package tutorial.rpc;

import haxe.io.Encoding;
import uuid.Uuid;
import amqp.helper.Bytes;
import amqp.message.Message;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class Client {
  private static var correlationId:String;
  private static var channel:Channel;
  private static var conn:Connection;
  private static var callbackQueue:String;
  private static var response:Bytes;

  /**
   * Call rpc function and sleep until return
   * @param num
   * @return Int
   */
  private static function call(num:Int):Int {
    response = null;
    correlationId = Uuid.v4();
    channel.basicPublish(
      '',
      'rpc_queue',
      Bytes.ofString(Std.string(num), Encoding.UTF8),
      {replyTo: callbackQueue, correlationId: correlationId,}
    );
    while (response == null) {
      // sleep a second to wait until possible answer
      Sys.sleep(1);
      // call receiveAcceptor manually since timers are blocked during sleep
      conn.receiveAcceptor();
    }
    return Std.parseInt(response.toString());
  }

  /**
   * Main entry point
   */
  public static function main():Void {
    // create connection instance
    var cfg:Config = new Config();
    // create connection instance
    conn = new Connection(cfg);
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
      channel = conn.channel((channel:Channel) -> {
        channel.declareQueue({queue: '', exclusive: true,}, (data:Dynamic) -> {
          // set callback queue
          callbackQueue = data.fields.queue;
          // consume channel
          channel.consumeQueue({queue: callbackQueue, noAck: true,}, (msg:Message) -> {
            if (msg.properties.correlationId == correlationId) {
              response = Bytes.ofData(msg.content.getData());
            }
          });
          // call fibonacci rpc
          trace(' [x] Requesting fib(30)');
          var response:Int = call(30);
          trace(' [.] Got ${response}');
        });
      });
    });
  }
}
