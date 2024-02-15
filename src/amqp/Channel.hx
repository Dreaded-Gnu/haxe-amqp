package amqp;

import amqp.channel.type.ConsumeQueue;
import haxe.io.Encoding;
import amqp.helper.Bytes;
import haxe.Exception;
import hxdispatch.Dispatcher;
import hxdispatch.Event;
import amqp.channel.config.Queue;
import amqp.helper.protocol.Constant;
import amqp.helper.protocol.EncoderDecoderInfo;
import amqp.channel.type.ChannelState;
import amqp.channel.type.BasicPublish;

class Channel extends Dispatcher<Dynamic> {
  public static inline var EVENT_ACK:Event = "ack";
  public static inline var EVENT_NACK:Event = "nack";
  public static inline var EVENT_CANCEL:Event = "cancel";

  private var connection:Connection;
  private var channelId:Int;
  private var state:ChannelState;
  private var expectedFrame:Array<Int>;
  private var expectedCallback:Array<(Dynamic)->Void>;

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
    this.expectedCallback = new Array<(frame:Dynamic)->Void>();
    this.expectedFrame = new Array<Int>();
    // register event handlers
    this.register(EVENT_ACK);
    this.register(EVENT_NACK);
    this.register(EVENT_CANCEL);
  }

  /**
   * Set expected information
   * @param method
   * @param callback
   * @return ->Void):Void
   */
  public function setExpected(method:Int, callback:(Dynamic)->Void):Void {
    if (null == callback) {
      throw new Exception( 'Callback for set expected is null!' );
    }
    this.expectedFrame.push(method);
    this.expectedCallback.push(callback);
  }

  /**
   * Basic accept method
   * @param frame
   */
  public function accept(frame:Dynamic):Void {
    try {
      var expected:Int = this.expectedFrame.length > 0 ? this.expectedFrame.shift() : 0;
      var callback:(field:Dynamic)->Void = this.expectedCallback.shift();
      // validate frame against expected
      this.validateExpectedFrame(expected, frame);
      // run expected callback if set
      if (callback != null)
      {
        // execute callback
        callback(frame);
        // skip rest
        return;
      }
    } catch ( e:Exception ) {
      // when exception occurs we got a mismatch
      this.connection.closeWithError(e.message, Constant.UNEXPECTED_FRAME);
      return;
    }
    trace(frame, frame.size?.low, frame.size?.high);
  }

  /**
   * Method to open the channel
   * @param callback
   */
  public function open(callback: (channel:Channel)->Void):Void {
    this.setExpected(
      EncoderDecoderInfo.ChannelOpenOk,
      (frame:Dynamic) -> {
        callback(this);
      }
    );
    this.connection.sendMethod(this.channelId, EncoderDecoderInfo.ChannelOpen, {outOfBand:""});
  }

  /**
   * Close channel
   * @param callback
   */
  public function close(callback:()->Void):Void {
    this.setExpected(
      EncoderDecoderInfo.ChannelCloseOk,
      (frame:Dynamic) -> {
        callback();
      }
    );
    this.connection.sendMethod(this.channelId, EncoderDecoderInfo.ChannelClose, {
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
  public function declareQueue(config:Queue, callback:()->Void):Void {
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

    this.setExpected(
      EncoderDecoderInfo.QueueDeclareOk,
      (frame:Dynamic) -> {
        callback();
      }
    );
    this.connection.sendMethod(
      this.channelId,
      EncoderDecoderInfo.QueueDeclare,
      fields
    );
  }

  /**
   * Consume a queue
   * @param config
   * @param callback
   */
  public function consumeQueue(config:ConsumeQueue, callback:(message:Dynamic)->Void):Void {
    // fill argument table
    var argt:Dynamic = {};
    if (Reflect.hasField(config, 'priority')) {
      Reflect.setField(argt, 'x-priority', config.priority);
    }
    // build fields
    var fields:Dynamic = {
      arguments: argt,
    };
    if (Reflect.hasField(config, 'ticket')) {
      Reflect.setField(fields, 'ticket', config.ticket);
    } else {
      Reflect.setField(fields, 'ticket', 0);
    }
    if (Reflect.hasField(config, 'queue')) {
      Reflect.setField(fields, 'queue', config.queue);
    }
    if (Reflect.hasField(config, 'consumerTag')) {
      Reflect.setField(fields, 'consumerTag', config.consumerTag);
    } else {
      Reflect.setField(fields, 'consumerTag', '');
    }
    if (Reflect.hasField(config, 'noLocal')) {
      Reflect.setField(fields, 'noLocal', config.noLocal);
    } else {
      Reflect.setField(fields, 'noLocal', false);
    }
    if (Reflect.hasField(config, 'noAck')) {
      Reflect.setField(fields, 'noAck', config.noAck);
    } else {
      Reflect.setField(fields, 'noAck', false);
    }
    if (Reflect.hasField(config, 'exclusive')) {
      Reflect.setField(fields, 'exclusive', config.exclusive);
    } else {
      Reflect.setField(fields, 'exclusive', false);
    }
    if (Reflect.hasField(config, 'nowait')) {
      Reflect.setField(fields, 'nowait', config.nowait);
    } else {
      Reflect.setField(fields, 'nowait', false);
    }
    // set expected frame and callback
    this.setExpected(
      EncoderDecoderInfo.BasicConsumeOk,
      (frame:Dynamic) -> {
        trace(frame);
        trace("bind callback!");
      }
    );
    // send method
    this.connection.sendMethod(
      this.channelId,
      EncoderDecoderInfo.BasicConsume,
      fields
    );
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
    this.connection.sendMessage(
      this.channelId,
      EncoderDecoderInfo.BasicPublish,
      methodFields,
      EncoderDecoderInfo.BasicProperties,
      propertyFields,
      message
    );
  }

  /**
   * Acknowledge a message
   * @param message
   * @param allUpTo
   */
  public function ack(message:Dynamic, allUpTo:Bool = false):Void {
    this.connection.sendMethod(
      this.channelId,
      EncoderDecoderInfo.BasicAck,
      {
        deliveryTag: message.fields.deliveryTag0,
        multiple: allUpTo,
      }
    );
  }

  /**
   * Acknowledge all messages
   */
  public function ackAll():Void {
    this.connection.sendMethod(
      this.channelId,
      EncoderDecoderInfo.BasicAck,
      {
        deliveryTag: 0,
        multiple: true,
      }
    );
  }

  /**
   * Not acknowledge a message
   * @param message
   * @param allUpTo
   * @param requeue
   */
  public function nack(message:Dynamic, allUpTo:Bool = false, requeue:Bool = false):Void {
    this.connection.sendMethod(
      this.channelId,
      EncoderDecoderInfo.BasicNack,
      {
        deliveryTag: message.fields.deliveryTag,
        multiple: allUpTo,
        requeue: requeue,
      }
    );
  }

  /**
   * Not acknowledge all messages
   * @param requeue
   */
  public function nackAll(requeue:Bool = false):Void {
    this.connection.sendMethod(
      this.channelId,
      EncoderDecoderInfo.BasicNack,
      {
        deliveryTag: 0,
        multiple: true,
        requeue: requeue,
      }
    );
  }

  /**
   * Reject a message
   * @param message
   * @param requeue
   */
  public function reject(message:Dynamic, requeue:Bool = false):Void {
    this.connection.sendMethod(
      this.channelId,
      EncoderDecoderInfo.BasicReject,
      {
        deliveryTag: message.fields.deliveryTag,
        requeue: requeue,
      }
    );
  }

  /**
   * Shutdown method
   */
  public function shutdown():Void {}
}
