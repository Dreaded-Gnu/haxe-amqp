package amqp;

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
  }
}