
import amqp.Connection;
import amqp.connection.Config;

class Main {
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
    while (true) {
    }
  }
}
