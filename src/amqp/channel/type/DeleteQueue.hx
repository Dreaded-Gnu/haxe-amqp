package amqp.channel.type;

typedef DeleteQueue = {
  @:optional var queue:String;
  @:optional var ticket:Int;
  @:optional var ifUnused:Bool;
  @:optional var ifEmpty:Bool;
  @:optional var nowait:Bool;
}
