package amqp.message;

import haxe.Int64;
import amqp.helper.Bytes;
import amqp.message.MessageFields;
import amqp.message.MessageProperties;

typedef Message = {
  @:optional var fields:MessageFields;
  @:optional var properties:MessageProperties;
  @:optional var message:MessageData;
  @:optional var size:Int64;
  @:optional var remaining:Int64;
  @:optional var content:Bytes;
};