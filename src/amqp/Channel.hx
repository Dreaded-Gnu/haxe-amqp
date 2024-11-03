package amqp;

import haxe.Exception;
import haxe.Int64;
import haxe.io.Encoding;
import emitter.signals.Emitter;
import promises.Promise;
import amqp.helper.BytesOutput;
import amqp.message.Message;
import amqp.helper.Bytes;
import amqp.helper.protocol.Constant;
import amqp.helper.protocol.EncoderDecoderInfo;
import amqp.channel.type.ChannelState;
import amqp.channel.type.BasicPublish;
import amqp.channel.type.ConsumeQueue;
import amqp.channel.type.Queue;
import amqp.channel.type.UnbindQueue;
import amqp.channel.type.UnbindExchange;
import amqp.channel.type.BindExchange;
import amqp.channel.type.DeleteExchange;
import amqp.channel.type.PurgeQueue;
import amqp.channel.type.DeleteQueue;
import amqp.channel.type.BindQueue;
import amqp.channel.type.DeclareExchange;
import amqp.channel.type.BasicQos;
import amqp.channel.type.OutgoingMessage;
import amqp.channel.type.Cancel;

/**
 * Channel class
 */
class Channel extends Emitter {
  /**
   * Event thrown when acknowledge is received
   */
  public static inline var EVENT_ACK:String = "ack";

  /**
   * Event thrown when not acknowledge is received
   */
  public static inline var EVENT_NACK:String = "nack";

  /**
   * Event thrown when cancel is received
   */
  public static inline var EVENT_CANCEL:String = "cancel";

  /**
   * Event thrown when error is detected
   */
  public static inline var EVENT_ERROR:String = "error";

  /**
   * Event thrown when channel is closed
   */
  public static inline var EVENT_CLOSED:String = "closed";

  /**
   * Property to get channel id via channel object
   */
  public var id(get, never):Int;

  private var connection:Connection;
  private var channelId:Int;
  private var state:ChannelState;
  private var expectedFrame:Array<Int>;
  private var expectedCallback:Array<(Dynamic) -> Void>;
  private var consumer:Map<String, Array<(Message) -> Void>>;
  private var incomingMessage:Message;
  private var incomingMessageBuffer:BytesOutput;
  private var outgoingMessageBuffer:Array<OutgoingMessage>;

  /**
   * Getter for property id
   * @return Int
   */
  private function get_id():Int {
    return channelId;
  }

  /**
   * Helper to validate expected frame
   * @param expected expected method
   * @param frame received frame
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
   * @param method method to send
   * @param fields data for method to send
   * @param expectedMethod expected return method
   * @param callback callback to be executed when expectedMethod matches
   */
  private function sendOrEnqueue(method:Int, fields:Dynamic, expectedMethod:Int, callback:(Dynamic) -> Void):Void {
    // handle closed
    if (this.state == ChannelStateClosed) {
      return;
    }
    // if one callback is in list, it will be sent out
    if (this.expectedCallback.length == 0 && this.outgoingMessageBuffer.length == 0) {
      // set expected
      if (expectedMethod != -1 && callback != null) {
        this.setExpected(expectedMethod, callback);
      }
      // execute send method
      this.connection.sendMethod(this.channelId, method, fields);
      // skip rest
      return;
    }
    // there is something ongoing so push to buffer
    this.outgoingMessageBuffer.push({
      method: method,
      fields: fields,
      expectedMethod: expectedMethod,
      callback: callback,
    });
  }

  /**
   * Constructor
   * @param connection connection instance
   * @param channelId id of the channel
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
    this.outgoingMessageBuffer = new Array<OutgoingMessage>();
  }

  /**
   * Force a connection state of the channel
   * @param state state to be enforced for this channeö
   */
  @:dox(hide) @:noCompletion public function forceConnectionState(state:ChannelState):Void {
    this.state = state;
  }

  /**
   * Set expected information
   * @param method expected method to be set
   * @param callback expected callback for method to be set
   */
  @:dox(hide) @:noCompletion public function setExpected(method:Int, callback:(Dynamic) -> Void):Void {
    if (null == callback) {
      throw new Exception('Callback for set expected is null!');
    }
    this.expectedFrame.push(method);
    this.expectedCallback.push(callback);
  }

  /**
   * Basic accept method
   * @param frame received decoded frame
   */
  @:dox(hide) @:noCompletion public function accept(frame:Dynamic):Void {
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
        // queue callback for execution
        this.connection.queueCallback(callback, frame);
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
        this.emit(EVENT_ACK, frame.fields);
      case EncoderDecoderInfo.BasicNack:
        this.emit(EVENT_NACK, frame.fields);
      case EncoderDecoderInfo.BasicCancel:
        this.emit(EVENT_CANCEL, frame.fields);
      case EncoderDecoderInfo.ChannelClose:
        // drain expected callback and frame
        this.expectedCallback = [];
        this.expectedFrame = [];
        // drain outgoing buffer
        this.outgoingMessageBuffer = [];
        // send channel close ok
        this.connection.sendMethod(this.channelId, EncoderDecoderInfo.ChannelCloseOk, {});
        var msg:String = 'Channel closed by server: ${frame.fields.replyCode} with message ${frame.fields.replyText}';
        this.emit(EVENT_ERROR, msg);
        // set state to closed
        this.state = ChannelStateClosed;
      default:
        if (this.outgoingMessageBuffer.length > 0 && this.expectedCallback.length == 0) {
          // get first element of pending messages
          var msg = this.outgoingMessageBuffer[0];
          // handle message existing
          if (msg != null) {
            // set expected
            if (msg.expectedMethod != -1 && msg.callback != null) {
              this.setExpected(msg.expectedMethod, msg.callback);
            }
            // send method
            this.connection.sendMethod(this.channelId, msg.method, msg.fields);
            // shift first element
            this.outgoingMessageBuffer.shift();
          }
        }
    }
  }

  /**
   * Method to open the channel
   * @return Channel promise resolving to channel
   */
  public function open():Promise<Channel> {
    return new Promise<Channel>((resolve:Channel->Void, reject:Any->Void) -> {
      // set channel state
      this.state = ChannelStateInit;
      // send channel open
      this.sendOrEnqueue(EncoderDecoderInfo.ChannelOpen, {outOfBand: ""}, EncoderDecoderInfo.ChannelOpenOk, (frame:Dynamic) -> {
        // set state to open
        this.state = ChannelStateOpen;
        // call callback
        resolve(this);
      });
    });
  }

  /**
   * Close channel
   * @returns Boolean promise resolving to true
   */
  public function close():Promise<Bool> {
    return new Promise<Bool>((resolve:Bool->Void, reject:Any->Void) -> {
      // handle state closed by executing the callback immediately
      if (this.state == ChannelStateClosed) {
        reject("channel already closed!");
        return;
      }
      // send or enqueue
      this.sendOrEnqueue(EncoderDecoderInfo.ChannelClose, {
        replyText: 'Goodbye',
        replyCode: Constant.REPLY_SUCCESS,
        methodId: 0,
        classId: 0,
      }, EncoderDecoderInfo.ChannelCloseOk, (frame:Dynamic) -> {
        // set state to closed
        this.state = ChannelStateClosed;
        // remove consumer
        this.consumer.clear();
        // remove channel from connection
        this.connection.channelCleanup(this);
        // execute callback
        resolve(true);
      });
    });
  }

  /**
   * Method to declare a queue
   * @param config declare queue configuration
   * @returns Promise with dynamic data
   */
  public function declareQueue(config:Queue):Promise<Dynamic> {
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
    return new Promise<Dynamic>((resolve:Dynamic->Void, reject:Any->Void) -> {
      this.sendOrEnqueue(EncoderDecoderInfo.QueueDeclare, fields, EncoderDecoderInfo.QueueDeclareOk, (frame:Dynamic) -> {
        resolve(frame);
      });
    });
  }

  /**
   * Bind queue
   * @param options bind queue options
   * @returns Boolean promise resolving to true
   */
  public function bindQueue(options:BindQueue):Promise<Bool> {
    return new Promise<Bool>((resolve:Bool->Void, reject:Any->Void) -> {
      this.sendOrEnqueue(EncoderDecoderInfo.QueueBind, options, EncoderDecoderInfo.QueueBindOk, (frame:Dynamic) -> {
        resolve(true);
      });
    });
  }

  /**
   * Unbind a queue
   * @param options unbind queue options
   * @returns Boolean promise resolving to true
   */
  public function unbindQueue(options:UnbindQueue):Promise<Bool> {
    return new Promise<Bool>((resolve:Bool->Void, reject:Any->Void) -> {
      this.sendOrEnqueue(EncoderDecoderInfo.QueueUnbind, options, EncoderDecoderInfo.QueueUnbindOk, (frame:Dynamic) -> {
        resolve(true);
      });
    });
  }

  /**
   * Consume a queue
   * @param config consume queue configuration
   * @param consumeCallback callback to be bound for consuming the queue
   * @returns String promise resolving to consumerTag
   */
  public function consumeQueue(config:ConsumeQueue, consumeCallback:(Message) -> Void):Promise<String> {
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
    return new Promise<String>((resolve:String->Void, reject:Any->Void) -> {
      // send method
      this.sendOrEnqueue(EncoderDecoderInfo.BasicConsume, fields, EncoderDecoderInfo.BasicConsumeOk, (frame:Dynamic) -> {
        // get bound callbacks
        var a:Array<(Message) -> Void> = this.consumer.get(frame.fields.consumerTag);
        // handle no callback existing
        if (a == null) {
          a = new Array<(Message) -> Void>();
        }
        // push back callback
        a.push(consumeCallback);
        // write back
        this.consumer.set(frame.fields.consumerTag, a);
        // execute normal callback
        resolve(frame.fields.consumerTag);
      });
    });
  }

  /**
   * Delete a queue
   * @param config delete queue config
   * @returns Int promise resolving to message count
   */
  public function deleteQueue(config:DeleteQueue):Promise<Int> {
    return new Promise<Int>((resolve:Int->Void, reject:Any->Void) -> {
      this.sendOrEnqueue(EncoderDecoderInfo.QueueDelete, config, EncoderDecoderInfo.QueueDeleteOk, (frame:Dynamic) -> {
        resolve(frame.fields.messageCount);
      });
    });
  }

  /**
   * Purge a queue
   * @param config purge queue config
   * @returns Int promise resolving to message count
   */
  public function purgeQueue(config:PurgeQueue):Promise<Int> {
    return new Promise<Int>((resolve:Int->Void, reject:Any->Void) -> {
      this.sendOrEnqueue(EncoderDecoderInfo.QueuePurge, config, EncoderDecoderInfo.QueuePurgeOk, (frame:Dynamic) -> {
        resolve(frame.fields.messageCount);
      });
    });
  }

  /**
   * Cancel a consumer
   * @param config cancel consume config
   * @returns Boolean promise resolving to true
   */
  public function cancel(config:Cancel):Promise<Bool> {
    return new Promise<Bool>((resolve:Bool->Void, reject:Any->Void) -> {
      this.sendOrEnqueue(EncoderDecoderInfo.BasicCancel, config, EncoderDecoderInfo.BasicCancelOk, (frame:Dynamic) -> {
        // remove consumers
        this.consumer.remove(config.consumerTag);
        // execute callback
        resolve(true);
      });
    });
  }

  /**
   * Declare exchange
   * @param config declare exchange config
   * @returns Boolean promise resolving to true
   */
  public function declareExchange(config:DeclareExchange):Promise<Bool> {
    return new Promise<Bool>((resolve:Bool->Void, reject:Any->Void) -> {
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
      // send method
      this.sendOrEnqueue(EncoderDecoderInfo.ExchangeDeclare, fields, EncoderDecoderInfo.ExchangeDeclareOk, (frame:Dynamic) -> {
        resolve(true);
      });
    });
  }

  /**
   * Delete an exchange
   * @param config delete exchange config
   * @returns Boolean promise resolving to true
   */
  public function deleteExchange(config:DeleteExchange):Promise<Bool> {
    return new Promise<Bool>((resolve:Bool->Void, reject:Any->Void) -> {
      this.sendOrEnqueue(EncoderDecoderInfo.ExchangeDelete, config, EncoderDecoderInfo.ExchangeDeleteOk, (frame:Dynamic) -> {
        resolve(true);
      });
    });
  }

  /**
   * Bind an exchange
   * @param config bind exchange config
   * @returns Boolean promise resolving to true
   */
  public function bindExchange(config:BindExchange):Promise<Bool> {
    return new Promise<Bool>((resolve:Bool->Void, reject:Any->Void) -> {
      this.sendOrEnqueue(EncoderDecoderInfo.ExchangeBind, config, EncoderDecoderInfo.ExchangeBindOk, (frame:Dynamic) -> {
        resolve(true);
      });
    });
  }

  /**
   * Unbind an exchange
   * @param config unbind exchange config
   * @returns Boolean promise resolving to true
   */
  public function unbindExchange(config:UnbindExchange):Promise<Bool> {
    return new Promise<Bool>((resolve:Bool->Void, reject:Any->Void) -> {
      this.sendOrEnqueue(EncoderDecoderInfo.ExchangeUnbind, config, EncoderDecoderInfo.ExchangeUnbindOk, (frame:Dynamic) -> {
        resolve(true);
      });
    });
  }

  /**
   * Basic publish method
   * @param exchange exchange to publish to
   * @param routingKey routing key for message
   * @param message message to send
   * @param options publish options
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
   * @param config QOS config
   * @returns Boolean promise resolving to true
   */
  public function basicQos(option:BasicQos):Promise<Bool> {
    return new Promise<Bool>((resolve:Bool->Void, reject:Any->Void) -> {
      this.sendOrEnqueue(EncoderDecoderInfo.BasicQos, option, EncoderDecoderInfo.BasicQosOk, (frame:Dynamic) -> {
        resolve(true);
      });
    });
  }

  /**
   * Acknowledge a message
   * @param message message to acknowledge
   * @param allUpTo acknowledge all deliveries up to this message
   */
  public function ack(message:Message, allUpTo:Bool = false):Void {
    this.sendOrEnqueue(EncoderDecoderInfo.BasicAck, {
      deliveryTag: message.fields.deliveryTag,
      multiple: allUpTo,
    }, -1, null);
  }

  /**
   * Acknowledge all messages
   */
  public function ackAll():Void {
    this.sendOrEnqueue(EncoderDecoderInfo.BasicAck, {
      deliveryTag: 0,
      multiple: true,
    }, -1, null);
  }

  /**
   * Not acknowledge a message
   * @param message message to not acknowledge
   * @param allUpTo not acknowledge all messages up to this message
   * @param requeue requeue not acknowledged messages
   */
  public function nack(message:Message, allUpTo:Bool = false, requeue:Bool = false):Void {
    this.sendOrEnqueue(EncoderDecoderInfo.BasicNack, {
      deliveryTag: message.fields.deliveryTag,
      multiple: allUpTo,
      requeue: requeue,
    }, -1, null);
  }

  /**
   * Not acknowledge all messages
   * @param requeue requeue not acknowledged messages
   */
  public function nackAll(requeue:Bool = false):Void {
    this.sendOrEnqueue(EncoderDecoderInfo.BasicNack, {
      deliveryTag: 0,
      multiple: true,
      requeue: requeue,
    }, -1, null);
  }

  /**
   * Reject a message
   * @param message message to reject
   * @param requeue requeue rejected message
   */
  public function reject(message:Message, requeue:Bool = false):Void {
    this.sendOrEnqueue(EncoderDecoderInfo.BasicReject, {
      deliveryTag: message.fields.deliveryTag,
      requeue: requeue,
    }, -1, null);
  }

  /**
   * Shutdown method
   */
  @:dox(hide) @:noCompletion public function shutdown():Void {
    this.expectedCallback = [];
    this.expectedFrame = [];
    this.outgoingMessageBuffer = [];
    this.state = ChannelStateClosed;
    this.emit(EVENT_CLOSED, "shutdown");
  }
}
