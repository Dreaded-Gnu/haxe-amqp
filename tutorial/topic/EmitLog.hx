package tutorial.topic;

import haxe.io.Encoding;
import amqp.helper.Bytes;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class EmitLog {
  /**
   * Main entry point
   */
  public static function main():Void {
    var args:Array<String> = Sys.args();
    // get routing key
    var routingKey:String = args.length > 0 ? args.shift() : 'anonymous.info';
    // build message
    var message:String = args.length > 0 ? args.join(' ') : 'Hello world';
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
        channel.declareExchange({exchange: 'topic_logs', type: 'topic'}, () -> {
          // publish a message
          channel.basicPublish('topic_logs', routingKey, Bytes.ofString(message, Encoding.UTF8));
          trace(' [x] Sent ${message}:${routingKey}');
          // close channel
          channel.close(() -> {
            trace("closing connection after channel was closed!");
            // close connection finally
            conn.close();
          });
        });
      });
    });
  }
}
