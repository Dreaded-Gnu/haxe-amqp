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
      this.connection.heartbeatStatus = true;
      trace( "heartbeat!" );
    } else if (frame.id == EncoderDecoderInfo.ConnectionClose) {
      trace( "close connection!" );
    } else if (frame.id == EncoderDecoderInfo.ConnectionBlocked) {
      trace( "connection blocked!") ;
    } else if (frame.id == EncoderDecoderInfo.ConnectionUnblocked) {
      trace("connection unblocked!");
    } else {
      trace( "Invalid package on control channel, close it up!" );
    }
    trace(frame, Frame.HEARTBEAT);
  }
}