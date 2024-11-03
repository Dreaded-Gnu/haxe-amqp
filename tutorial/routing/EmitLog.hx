package tutorial.routing;

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
    // get severity
    var severity:String = args.length > 0 ? args.shift() : 'info';
    // build message
    var message:String = args.length > 0 ? args.join(' ') : "Hello world";
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
        return channel.declareExchange({exchange: 'direct_logs', type: 'direct',}).then((declareStatus:Bool) -> {
          // publish a message
          channel.basicPublish('direct_logs', severity, Bytes.ofString(message, Encoding.UTF8));
          trace(' [x] Sent ${message} on severity ${severity}');
          return channel.close();
        });
      })
      .then((closeStatus) -> {
        trace("closing connection after channel was closed!");
        // close connection finally
        conn.close();
      });
  }
}
