package tutorial.hello_world;

import amqp.channel.config.Queue;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class Sender {
  public static function main() {
    // create connection instance
    var cfg:Config = new Config();
    // create connection instance
    var conn:Connection = new Connection(cfg);
    // add connected listener
    conn.attach(Connection.EVENT_CONNECTED, function(connection:Connection) {
      trace("Connected!");
      // create channel
      trace("create channel!");
      var channel:Channel = connection.channel();
      trace("create queue!");
      // create queue config
      var queueConfig:Queue = new Queue();
      queueConfig.queue = 'hello';
      // declare queue
      channel.declareQueue(queueConfig);
      trace("publish message!");
      // publish a message
      channel.basicPublish('', 'hello', 'hello world');
      // close channel finally
      trace("close connection!");
      conn.close();
    });
    // add closed listener
    conn.attach(Connection.EVENT_CLOSED, function(event:String) {
      trace(event);
    });
    // add error listener
    conn.attach(Connection.EVENT_ERROR, function(event:String) {
      trace(event);
    });
    // connect
    conn.connect();
    trace('Connected, yay');
    // sleep 10 seconds
    /*Sys.sleep(10);
    // close connection again
    conn.close();
    trace('Disconnected');*/
  }
}
