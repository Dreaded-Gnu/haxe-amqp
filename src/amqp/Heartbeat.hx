package amqp;

import haxe.Timer;
import emitter.Emitter;

/**
 * Heartbeat implementation
 */
@:dox(hide) class Heartbeat extends Emitter {
  /**
   * Event dispatched on heartbeat beat
   */
  public static inline var EVENT_BEAT:String = "beat";

  /**
   * Event dispatched on heartbeat timeout
   */
  public static inline var EVENT_TIMEOUT:String = "timeout";

  private static inline var MISSED_HEARTBEAT_FOR_TIMEOUT:Int = 2;

  private var interval:Int;
  private var checkReceive:() -> Bool;
  private var checkSend:() -> Bool;
  private var sendTimer:Timer;
  private var checkTimer:Timer;
  private var missedBeats:Int;

  /**
   * Constructor
   * @param interval heartbeat interval in seconds
   * @param checkReceive check received method
   * @param checkSend check sent method
   */
  public function new(interval:Int, checkReceive:() -> Bool, checkSend:() -> Bool) {
    // call parent constructor
    super();
    // save parameters to properties
    this.interval = interval * 1000; // store interval in milliseconds
    this.checkReceive = checkReceive;
    this.checkSend = checkSend;
    this.missedBeats = 0;
    // set timer
    this.sendTimer = new Timer(Std.int(this.interval / 2));
    this.sendTimer.run = this.send;
    this.checkTimer = new Timer(this.interval);
    this.checkTimer.run = this.receive;
  }

  /**
   * Clear heartbeater
   */
  public function clear():Void {
    // stop timer
    this.sendTimer.stop();
    this.checkTimer.stop();
    // clear all handler
    this.removeCallbacks(EVENT_BEAT);
    this.removeCallbacks(EVENT_TIMEOUT);
  }

  /**
   * Send callback
   */
  private function send():Void {
    // check for send
    if (!this.checkSend()) {
      this.emit(EVENT_TIMEOUT, this);
      return;
    }
    // emit beat event
    this.emit(EVENT_BEAT, this);
  }

  /**
   * Receive check callback
   */
  private function receive():Void {
    // check for timeout
    if (!this.checkReceive()) {
      this.missedBeats++;
    } else {
      this.missedBeats = 0;
    }
    // check against threshold
    if (this.missedBeats >= MISSED_HEARTBEAT_FOR_TIMEOUT) {
      this.emit(EVENT_TIMEOUT, this);
    }
  }
}
