package amqp.channel.type;

typedef BasicQos = {
  @:optional var prefetchCount:Int;
  @:optional var prefetchSize:Int;
  @:optional var global:Bool;
}
