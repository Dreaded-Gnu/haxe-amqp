package amqp.connection.type;

typedef TOpenFrameOpen = {
  var virtualHost:String;
  var capabilities:String;
  var insist:Bool;
}
