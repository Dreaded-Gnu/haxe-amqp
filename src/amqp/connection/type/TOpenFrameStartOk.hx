package amqp.connection.type;

import amqp.connection.type.TOpenFrameStartOkClientProperties;

typedef TOpenFrameStartOk = {
  var clientProperties:TOpenFrameStartOkClientProperties;
  var mechanism:String;
  var response:String;
  var locale:String;
}
