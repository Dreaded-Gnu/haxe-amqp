package amqp.connection.type;

import amqp.connection.type.TOpenFrameOpen;
import amqp.connection.type.TOpenFrameStartOk;
import amqp.connection.type.TOpenFrameTuneOk;

typedef TOpenFrame = {
  var startOk:TOpenFrameStartOk;
  var tuneOk:TOpenFrameTuneOk;
  var open:TOpenFrameOpen;
}
