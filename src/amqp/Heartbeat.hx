package amqp;

import haxe.Timer;
import emitter.signals.Emitter;

class Heartbeat extends Emitter {
  public static inline var EVENT_BEAT:String = "beat";
  public static inline var EVENT_TIMEOUT:String = "timeout";

  private static inline var MISSED_HEARTBEAT_FOR_TIMEOUT:Int = 2;

  private var interval:Int;
  private var checkHeartbeat:() -> Bool;
  private var sendTimer:Timer;
  private var checkTimer:Timer;
  private var missedBeats:Int;

  /**
   * Constructor
   * @param interval
   * @param checkHeartbeat
   */
  public function new(interval:Int, checkHeartbeat:() -> Bool) {
    // call parent constructor
    super();
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
    // clear all handler
    this.removeCallbacks(EVENT_BEAT);
    this.removeCallbacks(EVENT_TIMEOUT);
  }

  /**
   * Send callback
   */
  private function send():Void {
    // emit beat event
    this.emit(EVENT_BEAT, this);
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
      this.emit(EVENT_TIMEOUT, this);
    }
  }
}
