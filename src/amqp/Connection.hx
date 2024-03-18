package amqp;

import amqp.frame.type.DecodedFrame;
import haxe.Timer;
import haxe.Exception;
import sys.net.Host;
import sys.thread.Thread;
import hxdispatch.Dispatcher;
import hxdispatch.Event;
import amqp.connection.Config;
import amqp.connection.type.TOpenFrame;
import amqp.helper.Bytes;
import amqp.helper.BytesInput;
import amqp.helper.BytesOutput;
import amqp.helper.protocol.EncoderDecoderInfo;
import amqp.helper.protocol.Constant;

/**
 * Connection class
 */
class Connection extends Dispatcher<Dynamic> {
  public static inline var EVENT_CLOSED:Event = "closed";
  public static inline var EVENT_ERROR:Event = "error";
  public static inline var EVENT_BLOCKED:Event = "blocked";
  public static inline var EVENT_UNBLOCKED:Event = "unblocked";

  private static inline var SINGLE_CHUNK_THRESHOLD:Int = 2048;
  private static inline var ACCEPTOR_TIMEOUT:Int = 250;

  public var config(default, null):Config;
  public var sock(default, null):sys.net.Socket;
  public var output(default, null):BytesOutput;
  public var closed(default, null):Bool;
  public var heartbeatStatus(default, default):Bool;

  private var rest:BytesOutput;
  private var receiveTimer:Timer;
  private var thread:Thread;
  private var frame:Frame;
  private var channelMap:Map<Int, Channel>;
  private var serverProperties:Dynamic;
  private var channelMax:Int;
  private var frameMax:Int;
  private var heartbeat:Int;
  private var heartbeater:Heartbeat;
  private var nextChannelId:Int;

  /**
   * Constructor
   * @param config
   */
  public function new(config:Config) {
    super();
    this.config = config;
    this.output = new BytesOutput();
    this.frame = new Frame();
    this.frameMax = Constant.FRAME_MIN_SIZE;
    this.heartbeatStatus = false;
    this.rest = new BytesOutput();
    // register event callbacks
    this.register(EVENT_CLOSED);
    this.register(EVENT_ERROR);
    this.register(EVENT_BLOCKED);
    this.register(EVENT_UNBLOCKED);
  }

  /**
   * macro function to get compiler version
   */
  static macro function getCompilerVersion() {
    return macro $v{haxe.macro.Context.definedValue('haxe_ver')};
  }

  /**
   * Function returning open frames information for handshake
   */
  private function openFrames():TOpenFrame {
    return cast {
      // start-ok
      startOk: {
        clientProperties: {
          product: 'haxe-amqp',
          version: '0.0.1',
          platform: 'haxe ${getCompilerVersion()}',
          copyright: 'Copyright (c) 2024 Christian Freitag and/or its subsidiaries',
          information: 'https://github.com/Dreaded-Gnu/haxe-amqp',
          capabilities: {
            'publisher_confirms': true,
            'basic.nack': true,
            'consumer_cancel_notify': true,
            'exchange_exchange_bindings': true,
            'connection.blocked': true,
            'authentication_failure_close': true,
          },
        },
        mechanism: this.config.loginMethod,
        response: this.config.loginResponse,
        locale: this.config.locale,
      },

      // tune-ok
      tuneOk: {
        channelMax: 0,
        frameMax: 0x1000,
        heartbeat: this.config.heartbeat,
      },

      // open
      open: {
        virtualHost: this.config.vhost,
        capabilities: '',
        insist: this.config.insist,
      },
    };
  }

  /**
   * Static socket reader for extra thread
   */
  private static function socketReader() {
    var connection:Connection = cast Thread.readMessage(true);
    while (!connection.closed) {
      try {
        // read byte and write to output
        connection.output.writeByte(connection.sock.input.readByte());
      } catch (e:Dynamic) {
        if (Std.isOfType(e, haxe.io.Eof) || e == haxe.io.Eof) {
          // eof only handled for non secure since it throws eof
          // in secure sockets, when there is no further data
          if (!connection.config.isSecure) {
            trace('Eof, reader thread exiting...');
            return;
          }
        } else if (e == haxe.io.Error.Blocked) {
          // trace( 'Blocked!' );
        } else {
          trace('Uncaught: ${e}'); // throw e;
        }
      }
    }
  }

  /**
   * Helper to check heartbeat status with reset
   * @return Bool
   */
  private function checkHeartbeat():Bool {
    var status:Bool = this.heartbeatStatus;
    this.heartbeatStatus = false;
    return status;
  }

  /**
   * Helper to send heartbeat
   */
  private function sendHeartbeat():Void {
    // get heartbeat buffer
    var bytes:Bytes = Frame.HEARTBEAT_BUFFER;
    // just send it
    this.sock.output.writeFullBytes(bytes, 0, bytes.length);
    // flush socket output
    this.sock.output.flush();
  }

  /**
   * Start the heartbeat
   */
  private function startHeartbeat():Void {
    // handle no heartbeat
    if (0 >= this.heartbeat) {
      return;
    }
    // create heartbeat instance
    this.heartbeater = new Heartbeat(this.heartbeat, this.checkHeartbeat);
    // attach beat handler
    this.heartbeater.attach(Heartbeat.EVENT_BEAT, (hb:Heartbeat) -> {
      if (this.closed) {
        return;
      }
      this.sendHeartbeat();
    });
    // attach timeout handler
    this.heartbeater.attach(Heartbeat.EVENT_TIMEOUT, (hb:Heartbeat) -> {
      if (this.closed) {
        return;
      }
      this.shutdown("heartbeat timeout");
    });
  }

  /**
   * Stop heartbeat
   */
  private function stopHeartbeat():Void {
    // clear heartbeat
    if (this.heartbeater != null) {
      this.heartbeater.clear();
    }
  }

  /**
   * Receive acceptor polling every second for new data
   */
  public function receiveAcceptor():Void {
    // fetch data from output buffer
    var bytes:Bytes = Bytes.ofData(this.output.getBytes().getData());
    // flush out
    this.output.flush();
    // handle no data
    if (bytes.length > 0) {
      // write to rest
      this.rest.writeBytes(bytes, 0, bytes.length);
    }
    // get everything from rest
    bytes = Bytes.ofData(this.rest.getBytes().getData());
    // flush rest
    this.rest.flush();
    // handle no data
    if (bytes.length == 0) {
      return;
    }
    // create bytes input accessor with big endian
    var input:BytesInput = new BytesInput(bytes);
    input.bigEndian = true;
    // parse frame
    var parsedFrame:DecodedFrame = this.frame.parseFrame(input, this.frameMax);
    // handle possible further stuff
    if (parsedFrame.rest.length > 0) {
      this.rest.writeBytes(parsedFrame.rest, 0, parsedFrame.rest.length);
    } else if (parsedFrame == null) {
      this.rest.writeBytes(bytes, 0, bytes.length);
    }
    // return decoded frame
    var decodedFrame:Dynamic = this.frame.decodeFrame(parsedFrame);
    // get channel
    var channel:Channel = this.channelMap.get(parsedFrame.channel);
    if (null == channel) {
      closeWithError("Invalid channel received!", Constant.CHANNEL_ERROR);
    } else {
      channel.accept(decodedFrame);
    }
  }

  /**
   * Helper to negotiate server and desired variable
   * @param server
   * @param desired
   * @return Int
   */
  private function negotiate(server:Int, desired:Int):Int {
    if (server == 0 || desired == 0) {
      // i.e., whichever places a limit, if either
      return Std.int(Math.max(server, desired));
    } else {
      return Std.int(Math.min(server, desired));
    }
  }

  /**
   * Connect to amqp with performing handshake
   * @param callback
   */
  public function connect(callback:() -> Void):Void {
    // generate socket
    if (this.config.isSecure) {
      // create ssl socket
      var sslSocket:sys.ssl.Socket = new sys.ssl.Socket();
      // set ca and certificate
      sslSocket.setCA(sys.ssl.Certificate.loadFile(this.config.sslCaCert));
      sslSocket.setCertificate(sys.ssl.Certificate.loadFile(this.config.sslCert), sys.ssl.Key.loadFile(this.config.sslKey));
      sslSocket.verifyCert = this.config.sslVerify;
      // set sock
      this.sock = sslSocket;
    } else {
      this.sock = new sys.net.Socket();
    }
    // set socket timeout
    this.sock.setTimeout(Math.max(this.config.writeTimeout, this.config.readTimeout));
    // connect to host
    this.sock.connect(new Host(this.config.host), this.config.port);
    // enable blocking and fast send
    this.sock.setBlocking(true);
    this.sock.setFastSend(true);
    this.closed = false;
    // perform ssl handshake
    if (this.config.isSecure) {
      cast(this.sock, sys.ssl.Socket).handshake();
    }

    // get opening frame content
    var openFrameData:TOpenFrame = openFrames();

    // create thread
    this.thread = Thread.create(socketReader);
    // send message to thread
    thread.sendMessage(this);

    // create new channel 0
    var channel:Channel0 = new Channel0(this, 0);
    // force channel state to be open for channel 0
    channel.forceConnectionState(ChannelStateOpen);
    // setup map
    this.channelMap = new Map<Int, Channel>();
    // insert instance for control channel 0
    this.channelMap.set(0, channel);
    // set next channel id
    this.nextChannelId = 1;
    // set receive timer
    this.receiveTimer = new Timer(ACCEPTOR_TIMEOUT);
    this.receiveTimer.run = this.receiveAcceptor;

    function onOpenOk(frame:Dynamic):Void {
      // store channel max, frame max and heartbeat
      this.channelMax = openFrameData.tuneOk.channelMax;
      this.frameMax = openFrameData.tuneOk.frameMax;
      this.heartbeat = openFrameData.tuneOk.heartbeat;
      // start heartbeat
      this.startHeartbeat();
      // execute callback
      callback();
    }

    function onTuneResponse(frame:Dynamic):Void {
      // adjust openFrameData tune ok according to return from server
      openFrameData.tuneOk.frameMax = negotiate(frame.fields.frameMax, openFrameData.tuneOk.frameMax);
      openFrameData.tuneOk.channelMax = negotiate(frame.fields.channelMax, openFrameData.tuneOk.channelMax);
      openFrameData.tuneOk.heartbeat = negotiate(frame.fields.heartbeat, openFrameData.tuneOk.heartbeat);
      // send tune ok
      sendMethod(0, EncoderDecoderInfo.ConnectionTuneOk, openFrameData.tuneOk);
      // set expected frame callback and id
      channel.setExpected(EncoderDecoderInfo.ConnectionOpenOk, onOpenOk);
      // send open message
      sendMethod(0, EncoderDecoderInfo.ConnectionOpen, openFrameData.open);
    }

    function onProtocolReturn(frame:Dynamic):Void {
      // check whether mechanism is supported
      var mechanisms:Array<String> = cast(frame.fields.mechanisms, String).split(' ');
      if (mechanisms.indexOf(openFrameData.startOk.mechanism) == -1) {
        throw new Exception('SASL mechanism ${openFrameData.startOk.mechanism} is not provided by the server');
      }
      // validate version
      if (!(frame.fields.versionMajor == 0 && frame.fields.versionMinor == 9)) {
        this.sock.close();
        throw new Exception('Unsupported protocol version detected: ${frame.fields.versionMajor}.${frame.fields.versionMinor}');
      }
      // save server properties
      this.serverProperties = frame.fields.serverProperties;

      // Send connection start ok
      channel.setExpected(EncoderDecoderInfo.ConnectionTune, onTuneResponse);
      this.sendMethod(0, EncoderDecoderInfo.ConnectionStartOk, openFrameData.startOk);
    }

    // set expected frame for channel0
    channel.setExpected(EncoderDecoderInfo.ConnectionStart, onProtocolReturn);
    // send protocol header
    var b:Bytes = Bytes.ofString(Frame.PROTOCOL_HEADER);
    this.sock.output.writeFullBytes(b, 0, b.length);
  }

  /**
   * Method to close connection
   * @param reason
   */
  public function close(reason:String = "close", code:Int = Constant.REPLY_SUCCESS):Void {
    // send close
    this.sendMethod(0, EncoderDecoderInfo.ConnectionClose, {
      replyText: reason,
      replyCode: code,
      methodId: 0,
      classId: 0,
    });
  }

  /**
   * Function generates a new channel
   * @param callback
   * @return Channel
   */
  public function channel(callback:(Channel) -> Void):Channel {
    // get next id
    var chlId:Int = this.nextChannelId++;
    // instanciate new channel
    var ch:Channel = new Channel(this, chlId);
    // push back to channel map
    this.channelMap.set(chlId, ch);
    // open channel
    ch.open(callback);
    // return created channel
    return ch;
  }

  /**
   * Close down with error
   * @param reason
   * @param code
   */
  public function closeWithError(reason:String, code:Int):Void {
    this.trigger(EVENT_ERROR, reason);
    this.close(reason, code);
  }

  /**
   * Helper method to send a method
   * @param channel
   * @param method
   * @param fields
   */
  public function sendMethod(channel:Int, method:Int, fields:Dynamic):Void {
    // encode method
    var frame:Bytes = EncoderDecoderInfo.encodeMethod(method, channel, fields);
    // write to network
    this.sock.output.writeFullBytes(frame, 0, frame.length);
    // flush socket output
    this.sock.output.flush();
  }

  /**
   * Wrapper to send a message
   * @param channel
   * @param method
   * @param methodFields
   * @param property
   * @param propertyFields
   * @param content
   */
  public function sendMessage(channel:Int, method:Int, methodFields:Dynamic, property:Int, propertyFields:Dynamic, content:Bytes):Int {
    // encode method and properties
    var mframe:Bytes = EncoderDecoderInfo.encodeMethod(method, channel, methodFields);
    var pframe:Bytes = EncoderDecoderInfo.encodeProperties(property, channel, content.length, propertyFields);
    // determine length
    var methodHeaderLength:Int = mframe.length + pframe.length;
    var bodyLength:Int = content.length > 0 ? content.length + Constant.FRAME_OVERHEAD : 0;
    var totalLength:Int = methodHeaderLength + bodyLength;

    if (totalLength < SINGLE_CHUNK_THRESHOLD) {
      // build send package
      var output:BytesOutput = new BytesOutput();
      output.writeBytes(mframe, 0, mframe.length);
      output.writeBytes(pframe, 0, pframe.length);
      var bodyFrame:Bytes = this.frame.makeBodyFrame(channel, content);
      output.writeBytes(bodyFrame, 0, bodyFrame.length);
      // translate into bytes wrapper
      var frame:Bytes = Bytes.ofData(output.getBytes().getData());
      // write to network
      this.sock.output.writeFullBytes(frame, 0, frame.length);
      this.sock.output.flush();
      // return written length
      return bodyLength;
    }

    // write mframe and pframe
    if (methodHeaderLength < SINGLE_CHUNK_THRESHOLD) {
      // build send package
      var output:BytesOutput = new BytesOutput();
      output.writeBytes(mframe, 0, mframe.length);
      output.writeBytes(pframe, 0, pframe.length);
      // translate into bytes wrapper
      var frame:Bytes = Bytes.ofData(output.getBytes().getData());
      // write to network
      this.sock.output.writeFullBytes(frame, 0, frame.length);
      this.sock.output.flush();
    } else {
      this.sock.output.writeFullBytes(mframe, 0, mframe.length);
      this.sock.output.writeFullBytes(pframe, 0, pframe.length);
    }
    // send content finally
    return this.sendContent(channel, content);
  }

  /**
   * Wrapper to send content
   * @param channel
   * @param content
   * @return Int
   */
  public function sendContent(channel:Int, content:Bytes):Int {
    var maxBody:Int = this.frameMax - Constant.FRAME_OVERHEAD;
    var offset:Int = 0;
    var written:Int = 0;
    while (offset < content.length) {
      // calculate new end
      var end:Int = offset + maxBody;
      // cap end
      if (end > content.length) {
        end = content.length;
      }
      var slice:Bytes = content.sub(offset, end - offset);
      var bodyFrame:Bytes = this.frame.makeBodyFrame(channel, slice);
      // write to network
      this.sock.output.writeFullBytes(bodyFrame, 0, bodyFrame.length);
      this.sock.output.flush();
      // increase written
      written += bodyFrame.length;
      // increase offset
      offset += maxBody;
    }
    return written;
  }

  /**
   * Shutdown everything
   * @param reason
   */
  public function shutdown(reason:String = "shutdown"):Void {
    // shutdown all channels
    for (i in this.channelMap) {
      i.shutdown();
    }
    // overwrite channels
    this.channelMap = new Map<Int, Channel>();
    // stop heartbeater
    this.stopHeartbeat();
    // clear acceptor
    this.receiveTimer.stop();
    // set close flag and reset thread
    this.closed = true;
    this.thread = null;
    // finally close socket
    this.sock.close();
    // emit closed
    this.trigger(EVENT_CLOSED, reason);
  }
}
