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
    conn.connect()
      .then((connection:Connection) -> {
        trace("create channel!");
        // create channel
        return connection.channel();
      })
      .then((channel:Channel) -> {
        trace("declare queue!");
        // declare queue
        return channel.declareQueue({queue: QUEUE,}).then((frame:Dynamic) -> {
          trace("consume queue!");
          trace(frame);
          // consume queue
          return channel.consumeQueue({queue: QUEUE}, (message:Message) -> {}).then((id:String) -> {
            trace("cancel!");
            return channel.cancel({consumerTag: id}).then((cancelStatus:Bool) -> {
              trace("delete queue!");
              // delete queue again
              return channel.deleteQueue({queue: QUEUE,}).then((messageCount:Int) -> {
                trace("close channel!");
                return channel.close();
              });
            });
          });
        });
      })
      .then((channelCloseState:Bool) -> {
        trace("close connection!");
        // close connection
        conn.close();
      });
  }
}
