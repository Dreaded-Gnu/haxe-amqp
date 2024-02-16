package amqp.channel.type;

import amqp.channel.type.QueueArgument;

typedef Queue = {
  var queue:String;
  @:optional var arguments:QueueArgument;
  @:optional var ticket:Int;
  @:optional var passive:Bool;
  @:optional var durable:Bool;
  @:optional var exclusive:Bool;
  @:optional var autoDelete:Bool;
  @:optional var nowait:Bool;
}
