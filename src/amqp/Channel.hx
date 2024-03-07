package amqp;

import amqp.channel.type.UnbindQueue;
import amqp.channel.type.UnbindExchange;
import amqp.channel.type.BindExchange;
import amqp.channel.type.DeleteExchange;
import amqp.channel.type.PurgeQueue;
import amqp.channel.type.DeleteQueue;
import amqp.channel.type.BindQueue;
import amqp.channel.type.DeclareExchange;
import amqp.channel.type.BasicQos;
import haxe.Int64;
import amqp.helper.BytesOutput;
import amqp.message.Message;
import haxe.io.Encoding;
import amqp.helper.Bytes;
import haxe.Exception;
import hxdispatch.Dispatcher;
import hxdispatch.Event;
import amqp.helper.protocol.Constant;
import amqp.helper.protocol.EncoderDecoderInfo;
import amqp.channel.type.ChannelState;
import amqp.channel.type.BasicPublish;
import amqp.channel.type.ConsumeQueue;
import amqp.channel.type.Queue;

class Channel extends Dispatcher<Dynamic> {
  public static inline var EVENT_ACK:Event = "ack";
  public static inline var EVENT_NACK:Event = "nack";
  public static inline var EVENT_CANCEL:Event = "cancel";
  public static inline var EVENT_ERROR:Event = "error";
  public static inline var EVENT_CLOSED:Event = "closed";

  private var connection:Connection;
  private var channelId:Int;
  private var state:ChannelState;
  private var expectedFrame:Array<Int>;
  private var expectedCallback:Array<(Dynamic) -> Void>;
  private var consumer:Map<String, Array<(Message) -> Void>>;
  private var incomingMessage:Message;
  private var incomingMessageBuffer:BytesOutput;
  private var outgoingMessageBuffer:Array<{method:Int, fields:Dynamic}>;

  /**
   * Helper to validate expected frame
   * @param frame
   */
  private function validateExpectedFrame(expected:Int, frame:Dynamic):Void {
    // handle no expected frame
    if (expected == 0) {
      return;
    }
    // handle expected frame match
    if (expected == frame.id) {
      return;
    }
    // we got a mismatch, so throw an exception
    var expected:String = EncoderDecoderInfo.info(expected).name;
    var received:String = EncoderDecoderInfo.info(frame.id).name;
    throw new Exception('Expected ${expected} but got ${received}');
  }

  /**
   * Send or enqueue a message
   * @param method
   * @param fields
   */
  private function sendOrEnqueue(method:Int, fields:Dynamic):Void {
    // if one callback is in list, it will be sent out
    if (this.expectedCallback.length == 1) {
      this.connection.sendMethod(this.channelId, method, fields);
      return;
    }
    // there is something ongoing so push to buffer
    this.outgoingMessageBuffer.push({method: method, fields: fields,});
  }

  /**
   * Constructor
   * @param connection
   */
  public function new(connection:Connection, channelId:Int) {
    // call parent constructor
    super();
    // save connection
    this.connection = connection;
    this.channelId = channelId;
    this.state = ChannelStateInit;
    this.expectedCallback = new Array<(Dynamic) -> Void>();
    this.expectedFrame = new Array<Int>();
    this.consumer = new Map<String, Array<(Message) -> Void>>();
    this.incomingMessage = null;
    this.incomingMessageBuffer = new BytesOutput();
    this.outgoingMessageBuffer = [];
    // register event handlers
    this.register(EVENT_ACK);
    this.register(EVENT_NACK);
    this.register(EVENT_CANCEL);
    this.register(EVENT_ERROR);
  }

  /**
   * Force a connection state of the channel
   * @param state
   */
  public function forceConnectionState(state:ChannelState):Void {
    this.state = state;
  }

  /**
   * Set expected information
   * @param method
   * @param callback
   * @return ->Void):Void
   */
  public function setExpected(method:Int, callback:(Dynamic) -> Void):Void {
    if (null == callback) {
      throw new Exception('Callback for set expected is null!');
    }
    this.expectedFrame.push(method);
    this.expectedCallback.push(callback);
  }

  /**
   * Basic accept method
   * @param frame
   */
  public function accept(frame:Dynamic):Void {
    // check for closed
    if (this.state == ChannelStateClosed) {
      this.connection.closeWithError('Channel which is about to receive data is in closed state', Constant.UNEXPECTED_FRAME);
    }
    // handle callback
    try {
      var expected:Int = this.expectedFrame.length > 0 ? this.expectedFrame.shift() : 0;
      var callback:(Dynamic) -> Void = this.expectedCallback.shift();
      // validate frame against expected
      this.validateExpectedFrame(expected, frame);
      // run expected callback if set
      if (callback != null) {
        // execute callback
        callback(frame);
      }
    } catch (e:Exception) {
      // when exception occurs we got a mismatch
      this.connection.closeWithError(e.message, Constant.UNEXPECTED_FRAME);
      return;
    }

    switch (frame.id) {
      case null, EncoderDecoderInfo.BasicDeliver, EncoderDecoderInfo.BasicProperties:
        // ensure incoming message
        if (incomingMessage == null && frame.id != EncoderDecoderInfo.BasicDeliver) {
          throw new Exception("Invalid incoming message package");
        }
        // initialize incoming message property
        if (incomingMessage == null) {
          incomingMessage = {};
        }
        // handle basic deliver
        if (frame.id == EncoderDecoderInfo.BasicDeliver) {
          incomingMessage.fields = frame.fields;
        } else if (frame.id == EncoderDecoderInfo.BasicProperties) {
          incomingMessage.properties = frame.fields;
          incomingMessage.size = incomingMessage.remaining = frame.size;
        } else {
          // cast content to bytes instance
          var content:Bytes = cast(frame.content, Bytes);
          // get size
          var size:Int64 = Int64.ofInt(content.length);
          // decrease remaining
          incomingMessage.remaining -= size;
          // handle to much data send by server
          if (incomingMessage.remaining < 0) {
            throw new Exception("Received to much data for message!");
          }
          // write to buffer
          incomingMessageBuffer.writeBytes(content, 0, content.length);
          // handle remaining 0 => we're done
          if (incomingMessage.remaining == 0) {
            // push bytes
            incomingMessage.content = Bytes.ofData(incomingMessageBuffer.getBytes().getData());
            // get possible bound callbacks
            var callbacks:Array<(message:Message) -> Void> = this.consumer.get(incomingMessage.fields.consumerTag);
            // call callbacks
            if (null != callbacks) {
              for (callback in callbacks) {
                callback(incomingMessage);
              }
            }
            // reset incoming message and flush out buffer
            incomingMessage = null;
            incomingMessageBuffer.flush();
          }
        }
      case EncoderDecoderInfo.BasicAck:
        this.trigger(EVENT_ACK, frame.fields);
      case EncoderDecoderInfo.BasicNack:
        this.trigger(EVENT_NACK, frame.fields);
      case EncoderDecoderInfo.BasicCancel:
        this.trigger(EVENT_CANCEL, frame.fields);
      case EncoderDecoderInfo.ChannelClose:
        // drain expected callback and frame
        this.expectedCallback = [];
        this.expectedFrame = [];
        // drain outgoing buffer
        this.outgoingMessageBuffer = [];
        // send channel close ok
        this.connection.sendMethod(this.channelId, EncoderDecoderInfo.ChannelCloseOk, {});
        var msg:String = 'Channel closed by server: ${frame.fields.replyCode} with message ${frame.fields.replyText}';
        this.trigger(EVENT_ERROR, msg);
        // set state to closed
        this.state = ChannelStateClosed;
      default:
        // shift first element of pending messages
        var msg = this.outgoingMessageBuffer.shift();
        // handle message existing
        if (msg != null) {
          // send method
          this.connection.sendMethod(this.channelId, msg.method, msg.fields);
        }
    }
  }

  /**
   * Method to open the channel
   * @param callback
   */
  public function open(callback:(Channel) -> Void):Void {
    // set channel state
    this.state = ChannelStateInit;
    // set expected
    this.setExpected(EncoderDecoderInfo.ChannelOpenOk, (frame:Dynamic) -> {
      // set state to open
      this.state = ChannelStateOpen;
      // call callback
      callback(this);
    });
    // send channel open
    this.sendOrEnqueue(EncoderDecoderInfo.ChannelOpen, {outOfBand: ""});
  }

  /**
   * Close channel
   * @param callback
   */
  public function close(callback:() -> Void):Void {
    this.setExpected(EncoderDecoderInfo.ChannelCloseOk, (frame:Dynamic) -> {
      callback();
    });
    this.sendOrEnqueue(EncoderDecoderInfo.ChannelClose, {
      replyText: 'Goodbye',
      replyCode: Constant.REPLY_SUCCESS,
      methodId: 0,
      classId: 0,
    });
  }

  /**
   * Method to declare a queue
   * @param config
   * @param callback
   */
  public function declareQueue(config:Queue, callback:(data:Dynamic) -> Void):Void {
    // build arguments dynamic
    var arg:Dynamic = {};
    if (Reflect.hasField(config.arguments, "expires")) {
      Reflect.setField(arg, "x-expires", config.arguments.expires);
    }
    if (Reflect.hasField(config.arguments, "messageTtl")) {
      Reflect.setField(arg, "x-message-ttl", config.arguments.messageTtl);
    }
    if (Reflect.hasField(config.arguments, "deadLetterExchange")) {
      Reflect.setField(arg, "x-dead-letter-exchange", config.arguments.deadLetterExchange);
    }
    if (Reflect.hasField(config.arguments, "deadLetterRoutingKey")) {
      Reflect.setField(arg, "x-dead-letter-routing-key", config.arguments.deadLetterRoutingKey);
    }
    if (Reflect.hasField(config.arguments, "maxLength")) {
      Reflect.setField(arg, "x-max-length", config.arguments.maxLength);
    }
    if (Reflect.hasField(config.arguments, "maxPriority")) {
      Reflect.setField(arg, "x-max-priority", config.arguments.maxPriority);
    }
    if (Reflect.hasField(config.arguments, "overflow")) {
      Reflect.setField(arg, "x-overflow", config.arguments.overflow);
    }
    if (Reflect.hasField(config.arguments, "queueMode")) {
      Reflect.setField(arg, "x-queue-mode", config.arguments.queueMode);
    }
    // build fields object
    var fields:Dynamic = {
      queue: config.queue,
      exclusive: config.exclusive,
      durable: config.durable,
      autoDelete: config.autoDelete,
      arguments: arg,
      passive: config.passive,
      ticket: config.ticket,
      nowait: config.nowait,
    };

    this.setExpected(EncoderDecoderInfo.QueueDeclareOk, (frame:Dynamic) -> {
      callback(frame);
    });
    this.sendOrEnqueue(EncoderDecoderInfo.QueueDeclare, fields);
  }

  /**
   * Bind queue
   * @param options
   * @param callback
   */
  public function bindQueue(options:BindQueue, callback:() -> Void):Void {
    this.setExpected(EncoderDecoderInfo.QueueBindOk, (frame:Dynamic) -> {
      callback();
    });
    this.sendOrEnqueue(EncoderDecoderInfo.QueueBind, options);
  }

  /**
   * Unbind a queue
   * @param options
   * @param callback
   */
  public function unbindQueue(options:UnbindQueue, callback:() -> Void):Void {
    this.setExpected(EncoderDecoderInfo.QueueUnbindOk, (frame:Dynamic) -> {
      callback();
    });
    this.sendOrEnqueue(EncoderDecoderInfo.QueueUnbind, options);
  }

  /**
   * Consume a queue
   * @param config
   * @param callback
   */
  public function consumeQueue(config:ConsumeQueue, callback:(Message) -> Void):Void {
    // fill argument table
    var argt:Dynamic = {};
    if (Reflect.hasField(config, 'priority')) {
      Reflect.setField(argt, 'x-priority', config.priority);
    }
    // build fields
    var fields:Dynamic = {
      arguments: argt,
      ticket: config.ticket,
      queue: config.queue,
      consumerTag: config.consumerTag,
      noLocal: config.noLocal,
      noAck: config.noAck,
      exclusive: config.exclusive,
      nowait: config.nowait,
    };
    // set expected frame and callback
    this.setExpected(EncoderDecoderInfo.BasicConsumeOk, (frame:Dynamic) -> {
      // get bound callbacks
      var a:Array<(Message) -> Void> = this.consumer.get(frame.fields.consumerTag);
      // handle no callback existing
      if (a == null) {
        a = new Array<(Message) -> Void>();
      }
      // push back callback
      a.push(callback);
      // write back
      this.consumer.set(frame.fields.consumerTag, a);
    });
    // send method
    this.sendOrEnqueue(EncoderDecoderInfo.BasicConsume, fields);
  }

  /**
   * Delete a queue
   * @param config
   * @param callback
   */
  public function deleteQueue(config:DeleteQueue, callback:(messageCount:Int) -> Void):Void {
    // set expected frame and callback
    this.setExpected(EncoderDecoderInfo.QueueDeleteOk, (frame:Dynamic) -> {
      callback(frame.fields.messageCount);
    });
    // send method
    this.sendOrEnqueue(EncoderDecoderInfo.QueueDelete, config);
  }

  /**
   * Purge a queue
   * @param config
   * @param callback
   */
  public function purgeQueue(config:PurgeQueue, callback:(messageCount:Int) -> Void):Void {
    // set expected frame and callback
    this.setExpected(EncoderDecoderInfo.QueuePurgeOk, (frame:Dynamic) -> {
      callback(frame.fields.messageCount);
    });
    // send method
    this.sendOrEnqueue(EncoderDecoderInfo.QueuePurge, config);
  }

  /**
   * Declare exchange
   * @param config
   * @param callback
   */
  public function declareExchange(config:DeclareExchange, callback:() -> Void):Void {
    // build arguments dynamic
    var arg:Dynamic = {};
    if (Reflect.hasField(config, 'alternateExchange')) {
      Reflect.setField(arg, 'alternate-exchange', config.alternateExchange);
    }
    var fields:Dynamic = {
      exchange: config.exchange,
      ticket: config.ticket,
      type: config.type,
      passive: config.passive,
      durable: config.durable,
      autoDelete: config.autoDelete,
      internal: config.internal,
      nowait: config.nowait,
      arguments: arg
    };
    // set expected
    this.setExpected(EncoderDecoderInfo.ExchangeDeclareOk, (frame:Dynamic) -> {
      callback();
    });
    // send method
    this.sendOrEnqueue(EncoderDecoderInfo.ExchangeDeclare, fields);
  }

  /**
   * Delete an exchange
   * @param config
   * @param callback
   */
  public function deleteExchange(config:DeleteExchange, callback:() -> Void):Void {
    // set expected frame and callback
    this.setExpected(EncoderDecoderInfo.ExchangeDeleteOk, (frame:Dynamic) -> {
      callback();
    });
    // send method
    this.sendOrEnqueue(EncoderDecoderInfo.ExchangeDelete, config);
  }

  /**
   * Bind an exchange
   * @param config
   * @param callback
   */
  public function bindExchange(config:BindExchange, callback:() -> Void):Void {
    // set expected frame and callback
    this.setExpected(EncoderDecoderInfo.ExchangeBindOk, (frame:Dynamic) -> {
      callback();
    });
    // send method
    this.sendOrEnqueue(EncoderDecoderInfo.ExchangeBind, config);
  }

  /**
   * Unbind an exchange
   * @param config
   * @param callback
   */
  public function unbindExchange(config:UnbindExchange, callback:() -> Void):Void {
    // set expected frame and callback
    this.setExpected(EncoderDecoderInfo.ExchangeUnbindOk, (frame:Dynamic) -> {
      callback();
    });
    // send method
    this.sendOrEnqueue(EncoderDecoderInfo.ExchangeUnbind, config);
  }

  /**
   * Basic publish method
   * @param exchange
   * @param routingKey
   * @param message
   * @param options
   */
  public function basicPublish(exchange:String = '', routingKey:String = '', message:Bytes = null, options:BasicPublish = null):Void {
    if (message == null) {
      message = Bytes.ofString("", Encoding.UTF8);
    }
    // populate headers
    var headers:Dynamic = {};
    if (null != options?.BCC) {
      Reflect.setField(headers, 'BCC', options.BCC);
    }
    if (null != options?.CC) {
      Reflect.setField(headers, 'CC', options.CC);
    }
    // evaluate delivery mode
    var deliveryMode:Int = options?.persistant != null ? (options.persistant ? 2 : 1) : 1;
    // build fields for sending
    var methodFields:Dynamic = {
      // method fields
      exchange: exchange,
      routingKey: routingKey,
      mandatory: options?.mandatory != null ? options.mandatory : false,
      ticket: null,
    };
    // properties
    var propertyFields:Dynamic = {
      contentType: options?.contentType,
      contentEncoding: options?.contentEncoding,
      headers: headers,
      deliveryMode: deliveryMode,
      priority: options?.priority,
      correlationId: options?.correlationId,
      replyTo: options?.replyTo,
      expiration: options?.expiration,
      messageId: options?.messageId,
      timestamp: options?.timestamp,
      type: options?.type,
      userId: options?.userId,
      appId: options?.appId,
      clusterId: null
    }
    // finally send message
    this.connection.sendMessage(this.channelId, EncoderDecoderInfo.BasicPublish, methodFields, EncoderDecoderInfo.BasicProperties, propertyFields, message);
  }

  /**
   * Basic QOS
   * @param option
   * @param callback
   * @return ->Void):Void
   */
  public function basicQos(option:BasicQos, callback:() -> Void):Void {
    this.setExpected(EncoderDecoderInfo.BasicQosOk, (frame:Dynamic) -> {
      callback();
    });
    this.sendOrEnqueue(EncoderDecoderInfo.BasicQos, option);
  }

  /**
   * Acknowledge a message
   * @param message
   * @param allUpTo
   */
  public function ack(message:Message, allUpTo:Bool = false):Void {
    this.sendOrEnqueue(EncoderDecoderInfo.BasicAck, {
      deliveryTag: message.fields.deliveryTag,
      multiple: allUpTo,
    });
  }

  /**
   * Acknowledge all messages
   */
  public function ackAll():Void {
    this.sendOrEnqueue(EncoderDecoderInfo.BasicAck, {
      deliveryTag: 0,
      multiple: true,
    });
  }

  /**
   * Not acknowledge a message
   * @param message
   * @param allUpTo
   * @param requeue
   */
  public function nack(message:Message, allUpTo:Bool = false, requeue:Bool = false):Void {
    this.sendOrEnqueue(EncoderDecoderInfo.BasicNack, {
      deliveryTag: message.fields.deliveryTag,
      multiple: allUpTo,
      requeue: requeue,
    });
  }

  /**
   * Not acknowledge all messages
   * @param requeue
   */
  public function nackAll(requeue:Bool = false):Void {
    this.sendOrEnqueue(EncoderDecoderInfo.BasicNack, {
      deliveryTag: 0,
      multiple: true,
      requeue: requeue,
    });
  }

  /**
   * Reject a message
   * @param message
   * @param requeue
   */
  public function reject(message:Message, requeue:Bool = false):Void {
    this.sendOrEnqueue(EncoderDecoderInfo.BasicReject, {
      deliveryTag: message.fields.deliveryTag,
      requeue: requeue,
    });
  }

  /**
   * Shutdown method
   */
  public function shutdown():Void {
    this.expectedCallback = [];
    this.expectedFrame = [];
    this.outgoingMessageBuffer = [];
    this.state = ChannelStateClosed;
    this.trigger(EVENT_CLOSED, "shutdown");
  }
}
