package tutorial.ssl;

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
    cfg.isSecure = true;
    cfg.port = 5671;
    cfg.sslCaCert = 'cert/ca_certificate.pem';
    cfg.sslCert = 'cert/client_certificate.pem';
    cfg.sslKey = 'cert/client_key.pem';
    // create connection instance
    var conn:Connection = new Connection(cfg);
    // add closed listener
    conn.attach(Connection.EVENT_CLOSED, function(event:String) {
      trace(event);
    });
    // add error listener
    conn.attach(Connection.EVENT_ERROR, function(event:String) {
      trace(event);
    });
    // connect to amqp
    conn.connect(() -> {
      // create channel
      var channel:Channel = conn.channel((channel:Channel) -> {
        // declare queue
        channel.declareQueue({queue: QUEUE}, (frame:Dynamic) -> {
          // publish a message
          channel.basicPublish('', QUEUE, Bytes.ofString(MESSAGE, Encoding.UTF8));
          trace(' [x] Sent ${MESSAGE}');
          // close channel
          channel.close(() -> {
            trace("closing connection after channel was closed!");
            // close connection finally
            conn.close();
          });
        });
      });
    });
  }
}
