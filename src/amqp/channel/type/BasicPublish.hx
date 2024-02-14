package amqp.channel.type;

typedef BasicPublish = {
  @:optional var CC:Array<String>;
  @:optional var BCC:Array<String>;
  @:optional var persistant:Bool;
  @:optional var expiration:String;
  @:optional var contentType:String;
  @:optional var contentEncoding:String;
  @:optional var priority:Int;
  @:optional var correlationId:Int;
  @:optional var replyTo:String;
  @:optional var messageId:Int;
  @:optional var timestamp:Int;
  @:optional var type:String;
  @:optional var userId:String;
  @:optional var appId:String;
  @:optional var mandatory:Bool;
}
