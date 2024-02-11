package amqp.connection.type;

typedef TOpenFrameStartOkClientProperties = {
  var product:String;
  var version:String;
  var platform:String;
  var copyright:String;
  var information:String;
  var capabilities:Dynamic;
}
