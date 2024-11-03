package tutorial.publish_subscribe;

import amqp.message.Message;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class ReceiveLog {
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
    conn.connect().then((connection:Connection) -> {
      // create channel
      return connection.channel();
    }).then((channel:Channel) -> {
      // declare queue
      return channel.declareExchange({exchange: 'logs', type: 'fanout',}).then((exchangeState:Bool) -> {
        return channel.declareQueue({queue: '',}).then((data:Dynamic) -> {
          return channel.bindQueue({exchange: 'logs', queue: data.fields.queue}).then((bindStatus:Bool) -> {
            trace('[*] Waiting for logs. To exit press CTRL+C');
            return channel.consumeQueue({queue: data.fields.queue, noAck: true}, (msg:Message) -> {
              trace('[x] ${msg.content.toString()}');
            });
          });
        });
      }).then((consumerTag:String) -> {
        trace(' [*] Waiting for messages on ${consumerTag}. To exit press CTRL+C');
      });
    });
  }
}
