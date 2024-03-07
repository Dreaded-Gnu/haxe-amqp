package amqp.channel.type;

typedef PurgeQueue = {
  @:optional var queue:String;
  @:optional var ticket:Int;
  @:optional var nowait:Bool;
}
