package tutorial.hello_world;

import amqp.message.Message;
import amqp.channel.config.Queue;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class Receiver {
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
          // consume queue
          channel.consumeQueue({queue: QUEUE}, (message:Message) -> {
            if (message != null) {
              if (message.content != null) {
                trace('Received "${message.content.toString()}"');
              }
              channel.ack(message);
            }
          });
        });
      });
    });
  }
}
