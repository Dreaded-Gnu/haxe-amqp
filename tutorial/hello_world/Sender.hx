package tutorial.hello_world;

import amqp.Connection;
import amqp.connection.Config;

class Sender {
  public static function main() {
    // create connection instance
    var cfg:Config = new Config();
    // FIXME: FILL CONNECTION
    var conn:Connection = new Connection(cfg);
    conn.attach("connected", function(event:String) {
      trace(event);
    });
    // connect
    conn.connect();
    trace('Connected, yay');
    // sleep 10 seconds
    Sys.sleep(10);
    // close connection again
    conn.close();
    while (true) {
    }
  }
}
