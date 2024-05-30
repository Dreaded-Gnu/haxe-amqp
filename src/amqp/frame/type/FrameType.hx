package amqp.frame.type;

import haxe.Int32;
import amqp.helper.Bytes;

/**
 * Frame type
 */
typedef FrameType = {
  /**
   * type
   */
  var type:Int;

  /**
   * channel
   */
  var channel:Int;

  /**
   * size
   */
  var size:Int32;

  /**
   * remaining bytes
   */
  var rest:Bytes;
}
