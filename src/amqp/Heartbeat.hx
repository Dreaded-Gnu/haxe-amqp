package amqp;

import hxdispatch.Event;
import hxdispatch.Dispatcher;

class Heartbeat extends Dispatcher<Heartbeat> {
  public static inline var EVENT_BEAT:Event = "beat";
  public static inline var EVENT_TIMEOUT:Event = "timeout";

  private var interval:Int;
  private var checkSend:() -> Bool;
  private var checkReceive:() -> Bool;

  public function new(interval:Int, checkSend:() -> Bool, checkReceive:() -> Bool) {
    // call parent constructor
    super();
    // register events
    this.register(EVENT_BEAT);
    this.register(EVENT_TIMEOUT);
    // save parameters to properties
    this.interval = interval;
    this.checkSend = checkSend;
    this.checkReceive = checkReceive;
  }
}
