package amqp.frame.type;

import amqp.helper.Bytes;
import haxe.Int32;

/**
 * Frame method type
 */
typedef FrameMethodType = {
  /**
   * id
   */
  var id:Int32;

  /**
   * arguments
   */
  var args:Bytes;
}
