package amqp;

import haxe.Timer;
import hxdispatch.Event;
import hxdispatch.Dispatcher;

class Heartbeat extends Dispatcher<Heartbeat> {
  public static inline var EVENT_BEAT:Event = "beat";
  public static inline var EVENT_TIMEOUT:Event = "timeout";

  private static inline var MISSED_HEARTBEAT_FOR_TIMEOUT:Int = 2;

  private var interval:Int;
  private var checkHeartbeat:() -> Bool;
  private var sendTimer:Timer;
  private var checkTimer:Timer;
  private var missedBeats:Int;

  public function new(interval:Int, checkHeartbeat:() -> Bool) {
    // call parent constructor
    super();
    // register events
    this.register(EVENT_BEAT);
    this.register(EVENT_TIMEOUT);
    // save parameters to properties
    this.interval = interval * 1000; // store interval in milliseconds
    this.checkHeartbeat = checkHeartbeat;
    this.missedBeats = 0;
    // set timer
    this.sendTimer = new Timer(Std.int(this.interval / 2));
    this.sendTimer.run = this.send;
    this.checkTimer = new Timer(this.interval);
    this.checkTimer.run = this.receive;
  }

  /**
   * Clear timer
   */
  public function clear():Void {
    // stop timer
    this.sendTimer.stop();
    this.checkTimer.stop();
    // unregister events
    this.unregister(EVENT_BEAT);
    this.unregister(EVENT_TIMEOUT);
  }

  /**
   * Send callback
   */
  private function send():Void {
    // emit beat event
    this.trigger(EVENT_BEAT, this);
  }

  /**
   * Receive check callback
   */
  private function receive():Void {
    // check for timeout
    if (!this.checkHeartbeat()) {
      this.missedBeats++;
    } else {
      this.missedBeats = 0;
    }
    // check against threshold
    if (this.missedBeats >= MISSED_HEARTBEAT_FOR_TIMEOUT) {
      this.trigger(EVENT_TIMEOUT, this);
    }
  }
}
