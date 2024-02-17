package amqp.channel.type;

typedef DeclareExchange = {
  var exchange:String;
  var type:String;
  @:optional var alternateExchange:String;
  @:optional var ticket:Int;
  @:optional var passive:Bool;
  @:optional var durable:Bool;
  @:optional var autoDelete:Bool;
  @:optional var internal:Bool;
  @:optional var nowait:Bool;
}
