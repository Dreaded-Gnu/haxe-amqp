package tutorial.work_queues;

import amqp.message.Message;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class Worker {
  private static inline var QUEUE:String = 'task_queue';

  /**
   * Main entry point
   */
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
    conn.connect(() -> {
      // create channel
      var channel:Channel = conn.channel((channel:Channel) -> {
        // declare queue
        channel.declareQueue({queue: QUEUE, durable: true,}, () -> {
          // consume queue
          channel.consumeQueue({queue: QUEUE}, (message:Message) -> {
            if (message != null) {
              trace('Received "${message.content.toString()}"');
              Sys.sleep(message.content.length);
              channel.ack(message);
            }
          });
        });
      });
    });
  }
}