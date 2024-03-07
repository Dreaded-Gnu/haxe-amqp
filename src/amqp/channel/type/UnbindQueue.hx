package amqp.channel.type;

typedef UnbindQueue = {
  @:optional var ticket:Int;
  @:optional var queue:String;
  @:optional var exchange:String;
  @:optional var routingKey:String;
}
