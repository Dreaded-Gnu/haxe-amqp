package amqp.message;

import haxe.Int64;
import amqp.helper.Bytes;
import amqp.message.MessageFields;
import amqp.message.MessageProperties;

/**
 * Message object typedef
 */
typedef Message = {
  /**
   * Message fields
   */
  @:optional var fields:MessageFields;
  /**
   * Message properties
   */
  @:optional var properties:MessageProperties;
  /**
   * Message data
   */
  @:optional var message:MessageData;
  /**
   * Message size
   */
  @:optional var size:Int64;
  /**
   * Remaining size
   */
  @:optional var remaining:Int64;
  /**
   * Content
   */
  @:optional var content:Bytes;
}
