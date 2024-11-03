package tutorial.rpc;

import promises.Promise;
import haxe.io.Encoding;
import uuid.Uuid;
import amqp.helper.Bytes;
import amqp.message.Message;
import amqp.Channel;
import amqp.Connection;
import amqp.connection.Config;

class Client {
  /**
   * Main entry point
   */
  public static function main():Void {
    var inputData:Array<String> = Sys.args();
    // check for argument length
    if (0 >= inputData.length) {
      trace("Usage: Client [number]...");
      return;
    }
    var num:Int = Std.parseInt(inputData[0]);
    // create connection instance
    var cfg:Config = new Config();
    // create connection instance
    var conn:Connection = new Connection(cfg);
    var channel:Channel = null;
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
        return connection.channel();
      })
      .then((ch:Channel) -> {
        channel = ch;
        return new Promise((resolve, reject) -> {
          // build correlation id
          var correlationId:String = Uuid.v4();
          // maybe answer handling
          function maybeAnswer(msg:Message):Void {
            if (msg.properties.correlationId == correlationId) {
              resolve(msg.content.toString());
            }
          }
          // declare queue
          channel.declareQueue({queue: '', exclusive: true,})
            .then((frame:Dynamic) -> {
              // set callback queue
              return frame.fields.queue;
            })
            .then((callbackQueue:String) -> {
              // consume channel
              return channel.consumeQueue({queue: callbackQueue, noAck: true,}, maybeAnswer).then((consumerTag:String) -> {
                return callbackQueue;
              });
            })
            .then((callbackQueue:String) -> {
              trace(' [x] Requesting fib(${num})');
              channel.basicPublish('', 'rpc_queue', Bytes.ofString(Std.string(num), Encoding.UTF8), {replyTo: callbackQueue, correlationId: correlationId,});
            });
        });
      })
      .then((result:String) -> {
        trace(' [.] Got ${result}');
        return true;
      })
      .then((status:Bool) -> {
        return channel.close();
      })
      .then((closeChannelStatus:Bool) -> {
        conn.close();
      });
  }
}
