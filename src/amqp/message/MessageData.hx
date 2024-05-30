package amqp.message;

import amqp.helper.Bytes;

/**
 * Message data object
 */
typedef MessageData = {
  /**
   * Content
   */
  @:optional var content:Bytes;
}
