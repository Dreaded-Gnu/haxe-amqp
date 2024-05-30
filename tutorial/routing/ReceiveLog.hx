package tutorial.routing;

import amqp.message.Message;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class ReceiveLog {
  /**
   * Main entry point
   */
  public static function main():Void {
    var severities:Array<String> = Sys.args();
    // check for argument length
    if (0 >= severities.length) {
      trace("Usage: ReceiveLog [info] [warn] [error]");
      return;
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
    conn.connect(() -> {
      // create channel
      var channel:Channel = conn.channel((channel:Channel) -> {
        // declare queue
        channel.declareExchange({exchange: 'direct_logs', type: 'direct'}, () -> {
          channel.declareQueue({queue: '', exclusive: true,}, (data:Dynamic) -> {
            // bind severities
            for (severity in severities) {
              channel.bindQueue({exchange: 'direct_logs', queue: data.fields.queue, routingKey: severity,}, () -> {});
            }
            // consume queue
            trace('[*] Waiting for logs. To exit press CTRL+C');
            channel.consumeQueue({queue: data.fields.queue, noAck: true,}, (msg:Message) -> {
              trace('[x] ${msg.fields.routingKey} ${msg.content.toString()}');
            }, (consumerTag:String) -> {});
          });
        });
      });
    }, () -> {
      trace('failed to connect');
    });
  }
}
