package amqp;

import haxe.Exception;
import promises.Promise;
import amqp.channel.type.Cancel;
import amqp.channel.type.BasicQos;
import amqp.channel.type.BasicPublish;
import amqp.helper.Bytes;
import amqp.channel.type.UnbindExchange;
import amqp.channel.type.BindExchange;
import amqp.channel.type.DeleteExchange;
import amqp.channel.type.DeclareExchange;
import amqp.channel.type.PurgeQueue;
import amqp.channel.type.DeleteQueue;
import amqp.message.Message;
import amqp.channel.type.ConsumeQueue;
import amqp.channel.type.UnbindQueue;
import amqp.channel.type.BindQueue;
import amqp.channel.type.Queue;
import amqp.helper.protocol.Constant;
import amqp.helper.protocol.EncoderDecoderInfo;
import amqp.Channel;

/**
 * Internal implementation for control channel
 */
@:dox(hide) class Channel0 extends Channel {
  /**
   * Basic accept method
   * @param frame received decoded frame
   */
  override public function accept(frame:Dynamic):Void {
    // check for closed
    if (this.state == ChannelStateClosed) {
      this.connection.closeWithError('Channel which is about to receive data is in closed state', Constant.UNEXPECTED_FRAME);
    }
    // handle callback
    try {
      var expected:Int = this.expectedFrame.length > 0 ? this.expectedFrame.shift() : 0;
      var callback:(field:Dynamic) -> Void = this.expectedCallback.shift();
      // validate frame against expected
      this.validateExpectedFrame(expected, frame);
      // run expected callback if set
      if (callback != null) {
        // execute callback
        callback(frame);
        // skip rest
        return;
      }
    } catch (e:Exception) {
      // when exception occurs we got a mismatch
      this.connection.closeWithError(e.message, Constant.UNEXPECTED_FRAME);
      return;
    }

    if (frame.type == Constant.FRAME_HEARTBEAT) {
      // Do nothing on frame heartbeat
    } else if (frame.id == EncoderDecoderInfo.ConnectionClose) {
      // send close ok
      this.connection.sendMethod(0, EncoderDecoderInfo.ConnectionCloseOk, {});
      // shutdown everything
      this.connection.shutdown(frame.fields.replyText);
    } else if (frame.id == EncoderDecoderInfo.ConnectionCloseOk) {
      // shutdown everything
      this.connection.shutdown();
    } else if (frame.id == EncoderDecoderInfo.ConnectionBlocked) {
      this.connection.emit(Connection.EVENT_BLOCKED, "blocked");
    } else if (frame.id == EncoderDecoderInfo.ConnectionUnblocked) {
      this.connection.emit(Connection.EVENT_UNBLOCKED, "unblocked");
    } else {
      this.connection.closeWithError('Unexpected frame on channel 0, received ${EncoderDecoderInfo.info(frame.id).name}!', Constant.UNEXPECTED_FRAME);
    }
  }

  /**
   * Method to open the channel
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function open():Promise<Channel> {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Close channel
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function close():Promise<Bool> {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Method to declare a queue
   * @param config declare queue config
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function declareQueue(config:Queue):Promise<Dynamic> {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Bind queue
   * @param options bind queue config
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function bindQueue(options:BindQueue):Promise<Bool> {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Unbind a queue
   * @param options unbind queue config
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function unbindQueue(options:UnbindQueue):Promise<Bool> {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Consume a queue
   * @param config consume queue config
   * @param consumeCallback consume callback
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function consumeQueue(config:ConsumeQueue, consumeCallback:(Message) -> Void):Promise<String> {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Delete a queue
   * @param config delete queue config
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function deleteQueue(config:DeleteQueue):Promise<Int> {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Purge a queue
   * @param config purge queue config
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function purgeQueue(config:PurgeQueue):Promise<Int> {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Cancel a consumer
   * @param config cancel consumer config
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function cancel(config:Cancel):Promise<Bool> {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Declare exchange
   * @param config declare exchange config
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function declareExchange(config:DeclareExchange):Promise<Bool> {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Delete an exchange
   * @param config delete exchange config
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function deleteExchange(config:DeleteExchange):Promise<Bool> {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Bind an exchange
   * @param config bind exchange config
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function bindExchange(config:BindExchange):Promise<Bool> {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Unbind an exchange
   * @param config unbind exchange config
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function unbindExchange(config:UnbindExchange):Promise<Bool> {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Basic publish method
   * @param exchange exchange to publish to
   * @param routingKey routing key for message
   * @param message message to send
   * @param options publish options
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function basicPublish(exchange:String = '', routingKey:String = '', message:Bytes = null, options:BasicPublish = null):Void {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Basic QOS
   * @param option basic qos options
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function basicQos(option:BasicQos):Promise<Bool> {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Acknowledge a message
   * @param message message to acknowledge
   * @param allUpTo acknowledge all up to this message
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function ack(message:Message, allUpTo:Bool = false):Void {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Acknowledge all messages
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function ackAll():Void {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Not acknowledge a message
   * @param message message to not acknowledge
   * @param allUpTo all up to this message
   * @param requeue requeue messages
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function nack(message:Message, allUpTo:Bool = false, requeue:Bool = false):Void {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Not acknowledge all messages
   * @param requeue requeue messages
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function nackAll(requeue:Bool = false):Void {
    throw new Exception("Unsupported on channel 0");
  }

  /**
   * Reject a message
   * @param message message to reject
   * @param requeue requeue rejected message
   * @throws Exception Throws generally an exception since function is not supported on control channel
   */
  override public function reject(message:Message, requeue:Bool = false):Void {
    throw new Exception("Unsupported on channel 0");
  }
}
