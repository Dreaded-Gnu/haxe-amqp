package amqp.channel.type;

typedef BindQueue = {
  @:optional var queue:String;
  var exchange:String;
  @:optional var routingKey:String;
  @:optional var arguments:Dynamic;
  @:optional var ticket:Int;
  @:optional var nowait:Bool;
}
