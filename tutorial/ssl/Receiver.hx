package tutorial.ssl;

import amqp.message.Message;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class Receiver {
  private static inline var QUEUE:String = 'hello';
  private static inline var MESSAGE:String = 'hello world!';

  /**
   * Main entry point
   */
  public static function main():Void {
    // create connection instance
    var cfg:Config = new Config();
    cfg.isSecure = true;
    cfg.port = 5671;
    cfg.sslCaCert = 'cert/ca_certificate.pem';
    cfg.sslCert = 'cert/client_certificate.pem';
    cfg.sslKey = 'cert/client_key.pem';
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
        channel.declareQueue({queue: QUEUE,}, (frame:Dynamic) -> {
          // consume queue
          channel.consumeQueue({queue: QUEUE,}, (message:Message) -> {
            if (message != null) {
              if (message.content != null) {
                trace('Received "${message.content.toString()}"');
              }
              channel.ack(message);
            }
          }, (consumerTag:String) -> {});
        });
      });
    }, () -> {
      trace('failed to connect');
    });
  }
}
