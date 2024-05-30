package amqp.connection;

import amqp.helper.BytesOutput;
import haxe.Exception;
import amqp.helper.protocol.Constant;

class Config {
  /**
   * plain authentication
   */
  public static inline var AUTH_PLAIN:String = 'PLAIN';

  /**
   * Amqp plain authentication
   */
  public static inline var AUTH_AMQPPLAIN:String = 'AMQPLAIN';

  /**
   * External authentication
   */
  public static inline var AUTH_EXTERNAL:String = 'EXTERNAL';

  /**
   * Host
   */
  public var host(default, default):String = 'localhost';

  /**
   * Port
   */
  public var port(default, set):Int = 5672;

  /**
   * User
   */
  public var user(default, default):String = 'guest';

  /**
   * Password
   */
  public var password(default, default):String = 'guest';

  /**
   * vhost to connect to
   */
  public var vhost(default, set):String = '/';

  /**
   * insist flag used during connect
   */
  public var insist(default, default):Bool = false;

  /**
   * Login method used during connect
   */
  public var loginMethod(default, set):String = AUTH_PLAIN;

  /**
   * Login response used during connect
   */
  public var loginResponse(get, never):String;

  /**
   * Wanted locale
   */
  public var locale(default, set):String = 'en_US';

  /**
   * Socket read timeout
   */
  public var readTimeout(default, set):Float = 3.0;

  /**
   * Socket write timeout
   */
  public var writeTimeout(default, set):Float = 3.0;

  /**
   * heart beat delay in seconds used during connect
   */
  public var heartbeat(default, set):Int = 0;

  /**
   * Use ssl transport
   */
  public var isSecure(default, set):Bool = false;

  /**
   * CA Cert for ssl transport
   */
  public var sslCaCert(default, default):String;

  /**
   * Cert for ssl transport
   */
  public var sslCert(default, default):String;

  /**
   * Key for ssl transport
   */
  public var sslKey(default, default):String;

  /**
   * Verify ssl
   */
  public var sslVerify(default, set):Null<Bool>;

  /**
   * Constructor
   */
  public function new() {}

  /**
   * Setter for port property
   * @param port
   * @return Int
   */
  private function set_port(port:Int):Int {
    if (0 >= port) {
      throw new Exception('Port must be greater than 0');
    }
    return this.port = port;
  }

  /**
   * Setter for vhost property
   * @param vhost
   * @return String
   */
  private function set_vhost(vhost:String):String {
    if (null == vhost || 0 == vhost.length) {
      throw new Exception('vhost empty is not allowed');
    }
    return this.vhost = vhost;
  }

  /**
   * Setter for loginMethod property
   * @param loginMethod
   * @return String
   */
  private function set_loginMethod(loginMethod:String):String {
    // validate login method
    if (loginMethod != AUTH_PLAIN && loginMethod != AUTH_AMQPPLAIN && loginMethod != AUTH_EXTERNAL) {
      throw new Exception('Unknown login method $loginMethod');
    }
    // additional external method validation
    if (loginMethod == AUTH_EXTERNAL && (0 < this.user.length || 0 < this.password.length)) {
      throw new Exception('External auth method cannot be used together with user credentials');
    }
    return this.loginMethod = loginMethod;
  }

  /**
   * Getter for login response
   * @return String
   */
  private function get_loginResponse():String {
    if (this.loginMethod == Config.AUTH_AMQPPLAIN) {
      var output:BytesOutput = new BytesOutput();
      Codec.EncodeTable(output, {LOGIN: this.user, PASSWORD: this.password,});
      return output.getBytes().sub(4, output.length - 4).toString();
    } else if (this.loginMethod == Config.AUTH_PLAIN) {
      return ['', this.user, this.password].join(String.fromCharCode(0));
    } else if (this.loginMethod == Config.AUTH_EXTERNAL) {
      throw new Exception("External authentication not yet supported!");
    }
    return null;
  }

  /**
   * Setter for locale property
   * @param locale
   * @return String
   */
  private function set_locale(locale:String):String {
    if (null == locale || 0 == locale.length) {
      throw new Exception('locale empty is not allowed');
    }
    return this.locale = locale;
  }

  /**
   * Setter for readTimeout property
   * @param timeout
   * @return Float
   */
  private function set_readTimeout(timeout:Float):Float {
    if (0 > timeout) {
      throw new Exception('negative read timeout is not allowed');
    }
    return this.readTimeout = timeout;
  }

  /**
   * Setter for writeTimeout property
   * @param timeout
   * @return Float
   */
  private function set_writeTimeout(timeout:Float):Float {
    if (0 > timeout) {
      throw new Exception('negative write timeout is not allowed');
    }
    return this.writeTimeout = timeout;
  }

  /**
   * Setter for heartbeat property
   * @param heartbeat
   * @return Int
   */
  private function set_heartbeat(heartbeat:Int):Int {
    if (0 > heartbeat) {
      throw new Exception('negative heartbeat is not allowed');
    }
    return this.heartbeat = heartbeat;
  }

  /**
   * Setter for isSecure property
   * @param isSecure
   * @return Bool
   */
  private function set_isSecure(isSecure:Bool):Bool {
    return this.isSecure = isSecure;
  }

  /**
   * Setter for sslVerify property
   * @param val
   * @return Null<Bool>
   */
  private function set_sslVerify(val:Null<Bool>):Null<Bool> {
    this.sslVerify = val;
    return this.sslVerify;
  }
}
