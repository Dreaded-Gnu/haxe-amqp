package amqp;

import amqp.helper.protocol.Constant;
import amqp.helper.protocol.EncoderDecoderInfo;
import amqp.Channel;

/**
 * Special implementation for control channel
 */
class Channel0 extends Channel {
  /**
   * Accept override for special case for channel 0
   * @param frame
   */
  override public function accept(frame:Dynamic):Void {
    if (frame.type == Constant.FRAME_HEARTBEAT) {
      // set heartbeat status flag
      this.connection.heartbeatStatus = true;
    } else if (frame.id == EncoderDecoderInfo.ConnectionClose) {
      // send close ok
      this.connection.sendMethod(0, EncoderDecoderInfo.ConnectionCloseOk, {});
      // shutdown everything
      this.connection.shutdown();
    } else if (frame.id == EncoderDecoderInfo.ConnectionCloseOk) {
      // shutdown everything
      this.connection.shutdown();
    } else if (frame.id == EncoderDecoderInfo.ConnectionBlocked) {
      this.connection.trigger(Connection.EVENT_BLOCKED, "blocked");
    } else if (frame.id == EncoderDecoderInfo.ConnectionUnblocked) {
      this.connection.trigger(Connection.EVENT_UNBLOCKED, "unblocked");
    } else {
      this.connection.closeWithError("Unexpected frame on channel 0!", Constant.UNEXPECTED_FRAME);
    }
  }

  /**
   * Shutdown method
   */
  override public function shutdown():Void {}
}
