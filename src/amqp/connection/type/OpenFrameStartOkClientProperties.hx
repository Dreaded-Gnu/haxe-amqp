package amqp.connection.type;

/**
 * Open frame start ok client properties
 */
typedef OpenFrameStartOkClientProperties = {
  /**
   * product
   */
  var product:String;

  /**
   * version
   */
  var version:String;

  /**
   * platform
   */
  var platform:String;

  /**
   * copyright
   */
  var copyright:String;

  /**
   * information
   */
  var information:String;

  /**
   * capabilities
   */
  var capabilities:Dynamic;
}
