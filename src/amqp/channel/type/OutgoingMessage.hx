package amqp.channel.type;

/**
 * Typedef for outgoing cached message
 */
typedef OutgoingMessage = {
  /**
   * Method to send
   */
  var method:Int;

  /**
   * Method fields
   */
  var fields:Dynamic;

  /**
   * Expected return method
   */
  var expectedMethod:Int;

  /**
   * Callback executed on expected method
   */
  var callback:(Dynamic) -> Void;
};
