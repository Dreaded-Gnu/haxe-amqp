package amqp.channel.type;

typedef UnbindExchange = {
  @:optional var ticket:Int;
  var destination:String;
  var source:String;
  @:optional var routingKey:String;
  @:optional var nowait:Bool;
  @:optional var arguments:Dynamic;
}
