package tutorial.close_queue;

using thenshim.PromiseTools;

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
    trace("connect!");
    // connect to amqp
    conn.connect()
      .then((connection:Connection) -> {
        trace("create channel!");
        // create channel
        return connection.channel();
      })
      .then((ch:Channel) -> {
        channel = ch;
        trace("declare queue!");
        // declare queue
        return channel.declareQueue({queue: QUEUE,}).then((frame:Dynamic) -> {
          trace("consume queue!");
          trace(frame);
          // consume queue
          return channel.consumeQueue({queue: QUEUE}, (message:Message) -> {});
        });
      })
      .then((id:String) -> {
        consumerId = id;
        trace(consumerId);
        // var timer
        timer = new Timer(5000);
        trace(timer);
        timer.run = close;
      })
      .catchError((e:Dynamic) -> {
        trace(e);
      });
  }

  private static function close():Void {
    trace("timer stop!");
    // stop timer
    timer.stop();
    trace("cancel consume!");
    // cancel consume
    channel.cancel({consumerTag: consumerId,})
      .then((cancelStatus:Bool) -> {
        trace("delete queue!");
        // delete queue again
        return channel.deleteQueue({queue: QUEUE});
      })
      .then((messageCount:Int) -> {
        trace("close channel!");
        // close channel
        return channel.close();
      })
      .then((channelCloseState:Bool) -> {
        trace("close connection!");
        // close connection
        conn.close();
      });
  }
}
