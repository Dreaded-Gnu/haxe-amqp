package amqp.message;

import haxe.Int64;

typedef MessageFields = {
  @:optional var deliveryTag:Int64;
  @:optional var exchange:String;
  @:optional var consumerTag:String;
  @:optional var redelivered:Bool;
  @:optional var routingKey:String;
}
