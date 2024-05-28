package amqp.channel.type;

typedef Cancel = {
  var consumerTag:String;
  @:optional var nowait:Bool;
};
