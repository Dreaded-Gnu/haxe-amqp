package amqp;

import hxdispatch.Dispatcher;
import hxdispatch.Event;

class Channel extends Dispatcher<Dynamic> {
  public static inline var EVENT_ACK:Event = "ack";
  public static inline var EVENT_NACK:Event = "nack";
  public static inline var EVENT_CANCEL:Event = "cancel";
  public static inline var EVENT_OPEN:Event = "open";
  public static inline var EVENT_CLOSE:Event = "close";

  private var connection:Connection;

  /**
   * Constructor
   * @param connection
   */
  public function new(connection:Connection) {
    // call parent constructor
    super();
    // save connection
    this.connection = connection;
    // register event handlers
    this.register(EVENT_ACK);
    this.register(EVENT_NACK);
    this.register(EVENT_CANCEL);
    this.register(EVENT_OPEN);
    this.register(EVENT_CLOSE);
  }

  /**
   * Basic accept method
   * @param frame
   */
  public function accept(frame:Dynamic):Void {}

  /**
   * Method to open the channel
   */
  public function open():Void {}

  /**
   * Shutdown method
   */
  public function shutdown():Void {}
}
