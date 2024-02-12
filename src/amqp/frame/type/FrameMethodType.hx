package amqp.frame.type;

import amqp.helper.Bytes;
import haxe.Int32;

typedef FrameMethodType = {
  var id:Int32;
  var args:Bytes;
}
