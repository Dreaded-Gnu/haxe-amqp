package tutorial.work_queues;

import haxe.io.Encoding;
import amqp.helper.Bytes;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class NewTask {
  private static inline var QUEUE:String = 'task_queue';

  /**
   * Main entry point
   */
  public static function main():Void {
    var args:Array<String> = Sys.args();
    var message:String = "Hello world";
    // check for argument length
    if (0 < args.length) {
      message = args.join(' ');
    }
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
    conn.connect()
      .then((connection:Connection) -> {
        // create channel
        return connection.channel();
      })
      .then((channel:Channel) -> {
        return channel.declareQueue({queue: QUEUE, durable: true,}).then((frame:Dynamic) -> {
          // publish a message
          channel.basicPublish('', QUEUE, Bytes.ofString(message, Encoding.UTF8), {persistant: true,});
          trace(' [x] Sent ${message}');
          // close channel
          return channel.close();
        });
      })
      .then((closeState:Bool) -> {
        // close connection finally
        conn.close();
      });
  }
}
