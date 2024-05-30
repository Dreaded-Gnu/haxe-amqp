package tutorial.close_queue;

import haxe.Timer;
import amqp.message.Message;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class Close2 {
  private static inline var QUEUE:String = 'hello';
  private static var conn:Connection = null;
  private static var channel:Channel = null;

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
    trace("connect!");
    // connect to amqp
    conn.connect(() -> {
      trace("create channel!");
      // create channel
      channel = conn.channel((channel:Channel) -> {
        trace("declare queue!");
        // declare queue
        channel.declareQueue({queue: QUEUE,}, (frame:Dynamic) -> {
          trace("consume queue!");
          trace(frame);
          // consume queue
          channel.consumeQueue({queue: QUEUE}, (message:Message) -> {}, (id:String) -> {
            trace("cancel!");
            channel.cancel({consumerTag: id}, () -> {});
            trace("delete queue!");
            // delete queue again
            channel.deleteQueue({queue: QUEUE}, (messageCount:Int) -> {});
            trace("close channel!");
            // close channel
            channel.close(() -> {
              trace("close connection!");
              // close connection
              conn.close();
            });
          });
        });
      });
    }, () -> {
      trace('failed to connect');
    });
  }
}
