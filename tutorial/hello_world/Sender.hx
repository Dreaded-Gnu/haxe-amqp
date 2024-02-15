package tutorial.hello_world;

import haxe.io.Encoding;
import amqp.helper.Bytes;
import amqp.channel.config.Queue;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class Sender {
  private static inline var QUEUE:String = 'hello';
  private static inline var MESSAGE:String = 'hello world!';

  public static function main() {
    // create connection instance
    var cfg:Config = new Config();
    // create connection instance
    var conn:Connection = new Connection(cfg);
    // add closed listener
    conn.attach(Connection.EVENT_CLOSED, function(event:String) {
      trace(event);
    });
    // add error listener
    conn.attach(Connection.EVENT_ERROR, function(event:String) {
      trace(event);
    });
    // connect to amqp
    conn.connect(()-> {
      // create channel
      var channel:Channel = conn.channel((channel:Channel) -> {
        // create queue config
        var queueConfig:Queue = new Queue();
        queueConfig.queue = QUEUE;
        // declare queue
        channel.declareQueue(queueConfig, () -> {
          // publish a message
          channel.basicPublish('', 'hello', Bytes.ofString(MESSAGE, Encoding.UTF8));
          trace(' [x] Sent ${MESSAGE}');
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
