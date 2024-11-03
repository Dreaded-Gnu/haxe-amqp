package tutorial.routing;

using thenshim.PromiseTools;

import promises.Promise;
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
    conn.connect()
      .then((connection:Connection) -> {
        // create channel
        return connection.channel();
      })
      .then((channel:Channel) -> {
        // declare exchange
        return channel.declareExchange({exchange: 'direct_logs', type: 'direct',}).then((declareStatus:Bool) -> {
          return channel.declareQueue({queue: '', exclusive: true,}).then((data:Dynamic) -> {
            // bind severities
            var promise:Array<Promise<Bool>> = new Array<Promise<Bool>>();
            for (severity in severities) {
              promise.push(channel.bindQueue({exchange: 'direct_logs', queue: data.fields.queue, routingKey: severity,}));
            }
            // return promise all
            return promise.all().then((a:Array<Bool>) -> {
              // consume queue
              return channel.consumeQueue({queue: data.fields.queue, noAck: true,}, (msg:Message) -> {
                trace('[x] ${msg.fields.routingKey} ${msg.content.toString()}');
              });
            });
          });
        });
      })
      .then((consumerTag:String) -> {
        trace('[*] Waiting for logs on ${consumerTag}. To exit press CTRL+C');
      });
  }
}
