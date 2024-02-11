package amqp.connection.type;

typedef TOpenFrameTuneOk = {
  var channelMax:Int;
  var frameMax:Int;
  var heartbeat:Int;
}
