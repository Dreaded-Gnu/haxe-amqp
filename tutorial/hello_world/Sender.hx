package tutorial.hello_world;

import haxe.io.Encoding;
import amqp.helper.Bytes;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class Sender {
  private static inline var QUEUE:String = 'hello';
  private static inline var MESSAGE:String = 'hello world!';

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
    conn.connect()
      .then((connection:Connection) -> {
        return connection.channel();
      })
      .then((channel:Channel) -> {
        return channel.declareQueue({queue: QUEUE,}).then((frame:Dynamic) -> {
          channel.basicPublish('', QUEUE, Bytes.ofString(MESSAGE, Encoding.UTF8));
          trace(' [x] Sent ${MESSAGE}');
          return channel.close();
        });
      })
      .then((channelCloseState:Bool) -> {
        conn.close();
      });
  }
}
