package amqp.channel.type;

typedef DeleteExchange = {
  var exchange:String;
  @:optional var ticket:Int;
  @:optional var ifUnused:Bool;
  @:optional var nowait:Bool;
}
