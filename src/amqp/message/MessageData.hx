package amqp.message;

import amqp.helper.Bytes;

typedef MessageData = {
  @:optional var content:Bytes;
}