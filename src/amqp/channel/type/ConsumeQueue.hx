package amqp.channel.type;

typedef ConsumeQueue = {
  @:optional var priority:Int;
  @:optional var ticket:Int;
  @:optional var queue:String;
  @:optional var consumerTag:String;
  @:optional var noLocal:Bool;
  @:optional var noAck:Bool;
  @:optional var exclusive:Bool;
  @:optional var nowait:Bool;
}
