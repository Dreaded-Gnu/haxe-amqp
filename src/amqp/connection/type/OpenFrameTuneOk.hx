package amqp.connection.type;

/**
 * Open frame tune ok
 */
typedef OpenFrameTuneOk = {
  /**
   * max channels
   */
  var channelMax:Int;
  /**
   * max frame size
   */
  var frameMax:Int;
  /**
   * heartbeat delay
   */
  var heartbeat:Int;
}
