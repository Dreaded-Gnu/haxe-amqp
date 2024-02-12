package amqp;

import hxdispatch.Dispatcher;
import hxdispatch.Event;

class Channel extends Dispatcher<Dynamic> {
  public static inline var EVENT_ACK:Event = "ack";
  public static inline var EVENT_NACK:Event = "nack";
  public static inline var EVENT_CANCEL:Event = "cancel";

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
  }

  /**
   * Basic accept method
   * @param frame
   */
  public function accept(frame:Dynamic):Void {
  }
}