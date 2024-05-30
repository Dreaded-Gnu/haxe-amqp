package tutorial.rpc;

import haxe.io.Encoding;
import amqp.helper.Bytes;
import amqp.message.Message;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class Server {
  /**
   * Fibonacci function
   * @param n
   * @return Int
   */
  public static function fib(n:Int):Int {
    if (n == 0 || n == 1) {
      return n;
    }
    return fib(n - 1) + fib(n - 2);
  }

  /**
   * Main entry point
   */
  public static function main():Void {
    // create connection instance
    var cfg:Config = new Config();
    // create connection instance
    var conn:Connection = new Connection(cfg);
    // add closed listener
    conn.on(Connection.EVENT_CLOSED, function(event:String) {
      trace(event);
    });
    // add error listener
    conn.on(Connection.EVENT_ERROR, function(event:String) {
      trace(event);
    });
    // connect to amqp
    conn.connect(() -> {
      // create channel
      var channel:Channel = conn.channel((channel:Channel) -> {
        // declare queue
        channel.declareQueue({queue: 'rpc_queue',}, (data:Dynamic) -> {
          channel.basicQos({prefetchCount: 1,}, () -> {
            channel.consumeQueue({queue: 'rpc_queue',}, (msg:Message) -> {
              // get integer
              var num:Int = Std.parseInt(msg.content.toString());
              // some debug output
              trace(' [.]fib(${num})');
              // calculate response
              var response:Int = fib(num);
              // publish answer
              channel.basicPublish('', msg.properties.replyTo, Bytes.ofString(Std.string(response), Encoding.UTF8),
                {correlationId: msg.properties.correlationId});
              channel.ack(msg);
            }, (consumerTag:String) -> {});
          });
        });
      });
    }, () -> {
      trace('failed to connect');
    });
  }
}
