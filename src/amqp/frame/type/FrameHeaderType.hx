package amqp.frame.type;

import amqp.helper.Bytes;
import haxe.Int64;

/**
 * Frame header type
 */
typedef FrameHeaderType = {
  /**
   * amqp class
   */
  var klass:Int;

  /**
   * weight
   */
  var _weight:Int;

  /**
   * size
   */
  var size:Int64;

  /**
   * flags and fields as Bytes
   */
  var flagsAndfields:Bytes;
}
