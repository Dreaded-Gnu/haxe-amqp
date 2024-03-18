package amqp.connection;

import amqp.helper.BytesOutput;
import haxe.Exception;
import amqp.helper.protocol.Constant;

class Config {
  public static inline var AUTH_PLAIN:String = 'PLAIN';
  public static inline var AUTH_AMQPPLAIN:String = 'AMQPLAIN';
  public static inline var AUTH_EXTERNAL:String = 'EXTERNAL';

  public static inline var IO_TYPE_SOCKET:String = 'socket';

  public var ioType(default, set):String = IO_TYPE_SOCKET;
  public var isLazy(default, default):Bool = false;
  public var host(default, default):String = 'localhost';
  public var port(default, set):Int = 5672;
  public var user(default, default):String = 'guest';
  public var password(default, default):String = 'guest';
  public var vhost(default, set):String = '/';
  public var insist(default, default):Bool = false;
  public var loginMethod(default, set):String = AUTH_PLAIN;
  public var loginResponse(get, never):String;
  public var locale(default, set):String = 'en_US';
  public var connectionTimeout(default, set):Float = 3.0;
  public var readTimeout(default, set):Float = 3.0;
  public var writeTimeout(default, set):Float = 3.0;
  public var channelRpcTimeout(default, set):Float = 3.0;
  public var heartbeat(default, set):Int = 0;
  public var keepalive(default, default):Bool = false;
  public var isSecure(default, set):Bool = false;
  public var streamContext(default, set):Dynamic = null;
  public var sendBufferSize(default, set):Int = 0;
  public var dispatchSignals(default, default):Bool = true;
  public var protocolStrictFields(default, default):Bool = false;
  public var sslCaCert(default, default):String;
  public var sslCert(default, default):String;
  public var sslKey(default, default):String;
  public var sslVerify(default, set):Null<Bool>;
  public var sslVerifyName(default, default):Null<Bool>;
  public var sslPassPhrase(default, default):String;
  public var sslCiphers(default, default):String;
  public var sslSecurityLevel(default, default):Null<Int>;
  public var sslCryptoMethod(default, default):Null<Int>;
  public var connectionName(default, default):String = '';
  public var debugPackets(default, default):Bool = false;

  public function new() {}

  /**
   * Setter for ioType property
   * @param val
   * @return String
   */
  private function set_ioType(val:String):String {
    if (val != IO_TYPE_SOCKET) {
      throw new Exception('IO type can be only socket');
    }
    return this.ioType = val;
  }

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
   * Setter for connectionTimeout property
   * @param timeout
   * @return Float
   */
  private function set_connectionTimeout(timeout:Float):Float {
    if (0 > timeout) {
      throw new Exception('negative connection timeout is not allowed');
    }
    return this.connectionTimeout = timeout;
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
   * Setter for channelRpcTimeout property
   * @param timeout
   * @return Float
   */
  private function set_channelRpcTimeout(timeout:Float):Float {
    if (0 > timeout) {
      throw new Exception('negative channel rpc timeout is not allowed');
    }
    return this.channelRpcTimeout = timeout;
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
   * Setter for streamContext property
   * @param context
   * @return Dynamic
   */
  private function set_streamContext(context:Dynamic):Dynamic {
    return this.streamContext = context;
  }

  /**
   * Setter for sendBufferSize property
   * @param size
   * @return Int
   */
  private function set_sendBufferSize(size:Int):Int {
    if (0 < size) {
      throw new Exception('Negative send buffer size is not allowed');
    }
    return this.sendBufferSize = size;
  }

  /**
   * Setter for sslVerify property
   * @param val
   * @return Null<Bool>
   */
  private function set_sslVerify(val:Null<Bool>):Null<Bool> {
    this.sslVerify = val;
    if (null == this.sslVerify || !this.sslVerify) {
      this.sslVerifyName = false;
    }
    return this.sslVerify;
  }
}
