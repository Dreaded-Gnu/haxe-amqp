package tutorial.close_queue;

import haxe.Timer;
import amqp.message.Message;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class Close {
  private static inline var QUEUE:String = 'hello';
  private static inline var MESSAGE:String = 'hello world!';
  private static var conn:Connection = null;
  private static var channel:Channel = null;
  private static var timer:Timer = null;
  private static var consumerId:String = null;

  /**
   * Main entry point
   */
  public static function main():Void {
    // create connection instance
    var cfg:Config = new Config();
    // create connection instance
    conn = new Connection(cfg);
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
      channel = conn.channel((channel:Channel) -> {
        // declare queue
        channel.declareQueue({queue: QUEUE,}, (frame:Dynamic) -> {
          trace(frame);
          // consume queue
          channel.consumeQueue({queue: QUEUE}, (message:Message) -> {}, (id:String) -> {
            consumerId = id;
            trace(consumerId);
            // var timer
            timer = new Timer(5000);
            timer.run = close;
          });
        });
      });
    });
  }

  private static function close():Void {
    // stop timer
    timer.stop();
    // cancel consume
    channel.cancel({consumerTag: consumerId}, () -> {
      // delete queue again
      channel.deleteQueue({queue: QUEUE}, (messageCount:Int) -> {
        // close channel
        channel.close(() -> {
          // close connection
          conn.close();
        });
      });
    });
  }
}
