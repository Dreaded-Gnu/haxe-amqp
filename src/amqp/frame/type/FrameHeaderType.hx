package amqp.frame.type;

import amqp.helper.Bytes;
import haxe.Int64;

typedef FrameHeaderType = {
  var klass:Int;
  var _weight:Int;
  var size:Int64;
  var flagsAndfields:Bytes;
}
