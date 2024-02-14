package amqp.channel.config;

import amqp.channel.type.QueueArgument;

class Queue {
  public var queue(default, default):String;
  public var arguments(default, default):QueueArgument = {};
  public var ticket(default, default):Int = 0;
  public var passive(default, default):Bool = false;
  public var durable(default, default):Bool = false;
  public var exclusive(default, default):Bool = false;
  public var autoDelete(default, default):Bool = false;
  public var nowait(default, default):Bool = false;

  public function new() {}
}
