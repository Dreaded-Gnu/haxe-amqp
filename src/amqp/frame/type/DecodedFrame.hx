package amqp.frame.type;

import haxe.Int32;
import amqp.helper.Bytes;

typedef DecodedFrame = {
  var type:Int;
  var channel:Int;
  var size:Int32;
  var payload:Bytes;
  var rest:Bytes;
}
