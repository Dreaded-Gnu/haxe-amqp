package amqp.connection.type;

/**
 * Open frame open
 */
@:dox(hide) typedef OpenFrameOpen = {
  /**
   * vhost to be used
   */
  var virtualHost:String;

  /**
   * capabilities
   */
  var capabilities:String;

  /**
   * insist
   */
  var insist:Bool;
}
