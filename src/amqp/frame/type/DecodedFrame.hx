package amqp.frame.type;

import haxe.Int32;
import amqp.helper.Bytes;

/**
 * Decoded frame information
 */
typedef DecodedFrame = {
  /**
   * frame type
   */
  var type:Int;
  /**
   * used channel
   */
  var channel:Int;
  /**
   * frame size
   */
  var size:Int32;
  /**
   * frame bytes
   */
  var payload:Bytes;
  /**
   * remaining bytes not part of frame
   */
  var rest:Bytes;
}
