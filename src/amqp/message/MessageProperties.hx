package amqp.message;

import haxe.Int64;

typedef MessageProperties = {
  @:optional var appId:String;
  @:optional var contentEncoding:String;
  @:optional var messageId:Int;
  @:optional var deliveryMode:Int;
  @:optional var expiration:String;
  @:optional var contentType:String;
  @:optional var clusterId:String;
  @:optional var headers:Dynamic;
  @:optional var replyTo:String;
  @:optional var correlationId:String;
  @:optional var priority:Int;
  @:optional var type:String;
  @:optional var timestamp:Int64;
  @:optional var userId:String;
}
