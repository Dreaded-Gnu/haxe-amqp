package amqp.message;

import haxe.Int64;

/**
 * Message properties
 */
typedef MessageProperties = {
  /**
   * app id
   */
  @:optional var appId:String;
  /**
   * Encoding of content
   */
  @:optional var contentEncoding:String;
  /**
   * Message id
   */
  @:optional var messageId:Int;
  /**
   * Delivery mode
   */
  @:optional var deliveryMode:Int;
  /**
   * Expiration
   */
  @:optional var expiration:String;
  /**
   * Content type
   */
  @:optional var contentType:String;
  /**
   * Cluster id
   */
  @:optional var clusterId:String;
  /**
   * Headers
   */
  @:optional var headers:Dynamic;
  /**
   * Reply to information
   */
  @:optional var replyTo:String;
  /**
   * Correlation id
   */
  @:optional var correlationId:String;
  /**
   * Priority
   */
  @:optional var priority:Int;
  /**
   * Type
   */
  @:optional var type:String;
  /**
   * Timestamp
   */
  @:optional var timestamp:Int64;
  /**
   * user id
   */
  @:optional var userId:String;
}
