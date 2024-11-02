package amqp.connection.type;

import amqp.connection.type.OpenFrameOpen;
import amqp.connection.type.OpenFrameStartOk;
import amqp.connection.type.OpenFrameTuneOk;

/**
 * Open frame typedef used for connection
 */
@:dox(hide) typedef OpenFrame = {
  /**
   * Start ok
   */
  var startOk:OpenFrameStartOk;

  /**
   * tune ok
   */
  var tuneOk:OpenFrameTuneOk;

  /**
   * open
   */
  var open:OpenFrameOpen;
}
