package amqp.channel.type;

typedef QueueArgument = {
  @:optional var expires:Int;
  @:optional var messageTtl:Int;
  @:optional var deadLetterExchange:String;
  @:optional var deadLetterRoutingKey:String;
  @:optional var maxLength:Int;
  @:optional var maxPriority:Int;
  @:optional var overflow:String;
  @:optional var queueMode:String;
}
