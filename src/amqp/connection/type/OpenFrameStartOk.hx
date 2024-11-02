package amqp.connection.type;

import amqp.connection.type.OpenFrameStartOkClientProperties;

/**
 * Open frame start ok
 */
@:dox(hide) typedef OpenFrameStartOk = {
  /**
   * client properties
   */
  var clientProperties:OpenFrameStartOkClientProperties;

  /**
   * mechanism
   */
  var mechanism:String;

  /**
   * response
   */
  var response:String;

  /**
   * locale
   */
  var locale:String;
}
