package amqp.frame.type;

import haxe.Int32;
import amqp.helper.Bytes;

typedef FrameType = {
  var type:Int;
  var channel:Int;
  var size:Int32;
  var rest:Bytes;
}
