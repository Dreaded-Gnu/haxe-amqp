package amqp.message;

import haxe.Int64;

/**
 * Message fields
 */
typedef MessageFields = {
  /**
   * Delivery tag
   */
  @:optional var deliveryTag:Int64;
  /**
   * Used exchange
   */
  @:optional var exchange:String;
  /**
   * Consumer tag
   */
  @:optional var consumerTag:String;
  /**
   * Redelivered
   */
  @:optional var redelivered:Bool;
  /**
   * Used routing key
   */
  @:optional var routingKey:String;
}
