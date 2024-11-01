package amqp;

import haxe.MainLoop;
import haxe.Exception;
import sys.net.Host;
import sys.thread.Mutex;
import sys.thread.Thread;
import emitter.signals.Emitter;
import amqp.connection.Config;
import amqp.connection.type.OpenFrame;
import amqp.frame.type.DecodedFrame;
import amqp.helper.Bytes;
import amqp.helper.BytesInput;
import amqp.helper.BytesOutput;
import amqp.helper.protocol.EncoderDecoderInfo;
import amqp.helper.protocol.Constant;

/**
 * Connection class
 */
class Connection extends Emitter {
  /**
   * Event thrown when connection is closed
   */
  public static inline var EVENT_CLOSED:String = "closed";

  /**
   * Event thrown when error is detected
   */
  public static inline var EVENT_ERROR:String = "error";

  /**
   * Event thrown when connection is blocked
   */
  public static inline var EVENT_BLOCKED:String = "blocked";

  /**
   * Event thrown when connection is unblocked again
   */
  public static inline var EVENT_UNBLOCKED:String = "unblocked";

  private static inline var SINGLE_CHUNK_THRESHOLD:Int = 2048;

  /**
   * Config object
   */
  public var config(default, null):Config;

  private var sentSinceLastCheck:Bool;
  private var receivedSinceLastCheck:Bool;
  private var closed:Bool;
  private var output:BytesOutput;
  private var sock:sys.net.Socket;
  private var readMutex:Mutex;
  private var writeMutex:Mutex;
  private var rest:BytesOutput;
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
   * @param config configuration object
   */
  public function new(config:Config) {
    super();
    this.config = config;
    this.output = new BytesOutput();
    this.frame = new Frame();
    this.frameMax = Constant.FRAME_MIN_SIZE;
    this.rest = new BytesOutput();
    this.readMutex = new Mutex();
    this.writeMutex = new Mutex();
    this.sentSinceLastCheck = false;
    this.receivedSinceLastCheck = false;
  }

  /**
   * macro function to get compiler version
   */
  static macro function getCompilerVersion() {
    return macro $v{haxe.macro.Context.definedValue('haxe_ver')};
  }

  /**
   * Function returning open frames information for handshake
   * @return open frame object
   */
  private function openFrames():OpenFrame {
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
   * Helper to send bytes
   * @param bytes bytes to send
   */
  private function sendBytes(bytes:Bytes):Void {
    // aquire mutex
    this.writeMutex.acquire();
    // wait for write
    var result:{read:Array<sys.net.Socket>, write:Array<sys.net.Socket>, others:Array<sys.net.Socket>} = sys.net.Socket.select(null, [this.sock], null);
    // write data
    result.write[0].output.writeFullBytes(bytes, 0, bytes.length);
    // flush it
    result.write[0].output.flush();
    // set sent flag
    this.sentSinceLastCheck = true;
    // release mutex
    this.writeMutex.release();
  }

  /**
   * Socket reader called from main loop
   */
  private function socketReaderPoll():Void {
    // aquire mutex
    this.readMutex.acquire();
    // we've valid data for read
    try {
      // wait for data
      this.sock.waitForRead();
      // allocate chunk of data
      var data:Bytes = Bytes.alloc(1024);
      // loop endless
      while (true) {
        var read:Int = this.sock.input.readBytes(data, 0, data.length);
        // handle data read
        if (read > 0) {
          // write to output buffer
          this.output.writeBytes(data, 0, read);
        }
        // handle no more data
        if (read <= 0 || read < data.length) {
          break;
        }
      }
    } catch (e:Dynamic) {
      if (Std.isOfType(e, haxe.io.Eof) || e == haxe.io.Eof) {} else if (e == haxe.io.Error.Blocked) {} else {
        trace('Uncaught: ${e}'); // throw e;
      }
    }
    // release mutex
    this.readMutex.release();
    // execute receive acceptor
    this.receiveAcceptor();
  }

  /**
   * Helper to check heartbeat status with reset
   * @return heartbeat status
   */
  private function checkHeartbeat():Bool {
    var status:Bool = this.receivedSinceLastCheck;
    this.receivedSinceLastCheck = false;
    return status;
  }

  /**
   * Check send method
   * @return Bool
   */
  private function checkSend():Bool {
    var status:Bool = this.sentSinceLastCheck;
    this.sentSinceLastCheck = false;
    return status;
  }

  /**
   * Helper to send heartbeat
   */
  private function sendHeartbeat():Void {
    // just send it
    this.sendBytes(Frame.HEARTBEAT_BUFFER);
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
    this.heartbeater = new Heartbeat(this.heartbeat, this.checkHeartbeat, this.checkSend);
    // attach beat handler
    this.heartbeater.on(Heartbeat.EVENT_BEAT, (hb:Heartbeat) -> {
      if (this.closed) {
        return;
      }
      this.sendHeartbeat();
    });
    // attach timeout handler
    this.heartbeater.on(Heartbeat.EVENT_TIMEOUT, (hb:Heartbeat) -> {
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
    // try again flag set when there is further data
    var tryAgain:Bool = false;
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
    // handle no complete frame
    if (parsedFrame == null) {
      this.rest.writeBytes(bytes, 0, bytes.length);
      return;
      // handle possible further stuff
    } else if (parsedFrame.rest.length > 0) {
      // write back rest
      this.rest.writeBytes(parsedFrame.rest, 0, parsedFrame.rest.length);
      // set try again flag
      tryAgain = true;
    }
    // set received since last check to true
    this.receivedSinceLastCheck = true;
    // return decoded frame
    var decodedFrame:Dynamic = this.frame.decodeFrame(parsedFrame);
    // get channel
    var channel:Channel = this.channelMap.get(parsedFrame.channel);
    if (null == channel) {
      closeWithError("Invalid channel received!", Constant.CHANNEL_ERROR);
    } else {
      channel.accept(decodedFrame);
    }
    // handle try again
    if (tryAgain) {
      this.receiveAcceptor();
    }
  }

  /**
   * Helper to negotiate server and desired variable
   * @param server value from server
   * @param desired desired value
   * @return negotiated value
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
   * @param successCallback callback executed once connection handshake is
   * @param failureCallback callback executed when connection failed
   */
  public function connect(successCallback:() -> Void, failureCallback:() -> Void):Void {
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
    try {
      this.sock.connect(new Host(this.config.host), this.config.port);
    } catch (e:Any) {
      failureCallback();
      return;
    }
    // disable blocking and set fast send
    this.sock.setBlocking(false);
    this.sock.setFastSend(true);
    this.closed = false;

    // get opening frame content
    var openFrameData:OpenFrame = openFrames();

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

    function onOpenOk(frame:Dynamic):Void {
      // store channel max, frame max and heartbeat
      this.channelMax = openFrameData.tuneOk.channelMax;
      this.frameMax = openFrameData.tuneOk.frameMax;
      this.heartbeat = openFrameData.tuneOk.heartbeat;
      // new thread with event loop for receiving
      MainLoop.addThread(() -> {
        while (!this.closed) {
          // poll without wait
          this.socketReaderPoll();
          // sleep a tiny while
          Sys.sleep(0.01);
        }
      });
      // start heartbeat
      this.startHeartbeat();
      // execute successCallback
      successCallback();
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
      // poll data
      this.socketReaderPoll();
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
      // poll data
      this.socketReaderPoll();
    }

    // set expected frame for channel0
    channel.setExpected(EncoderDecoderInfo.ConnectionStart, onProtocolReturn);
    // send protocol header
    this.sendBytes(Bytes.ofString(Frame.PROTOCOL_HEADER));
    // poll data
    this.socketReaderPoll();
  }

  /**
   * Method to close connection
   * @param reason close reason for amqp
   * @param code close code
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
   * @param callback callback executed once channel is opened
   * @return Newly generated channel
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
   * Remove passed channel from map
   * @param channel Channel to cleanup from channel map
   */
  public function channelCleanup(channel:Channel):Void {
    if (this.channelMap.exists(channel.id)) {
      this.channelMap.remove(channel.id);
    }
  }

  /**
   * Close down with error
   * @param reason error reason
   * @param code error code
   */
  public function closeWithError(reason:String, code:Int):Void {
    this.emit(EVENT_ERROR, reason);
    this.close(reason, code);
  }

  /**
   * Helper method to send
   * @param channel used channel id
   * @param method method to send
   * @param fields fields with data for method
   */
  public function sendMethod(channel:Int, method:Int, fields:Dynamic):Void {
    // encode method
    var frame:Bytes = EncoderDecoderInfo.encodeMethod(method, channel, fields);
    // just send it
    this.sendBytes(frame);
  }

  /**
   * Wrapper to send a message
   * @param channel used channel id
   * @param method method to send
   * @param methodFields method fields
   * @param property property to send
   * @param propertyFields property fields
   * @param content content to send
   * @return written bytes
   */
  public function sendMessage(channel:Int, method:Int, methodFields:Dynamic, property:Int, propertyFields:Dynamic, content:Bytes):Int {
    // encode method and properties
    var mframe:Bytes = EncoderDecoderInfo.encodeMethod(method, channel, methodFields);
    var pframe:Bytes = EncoderDecoderInfo.encodeProperties(property, channel, content.length, propertyFields);
    // determine length
    var methodHeaderLength:Int = mframe.length + pframe.length;
    var bodyLength:Int = content.length > 0 ? content.length + Constant.FRAME_OVERHEAD : 0;
    var totalLength:Int = methodHeaderLength + bodyLength;

    // handle sendable within a single chunk
    if (totalLength < SINGLE_CHUNK_THRESHOLD) {
      // build send package
      var output:BytesOutput = new BytesOutput();
      output.writeBytes(mframe, 0, mframe.length);
      output.writeBytes(pframe, 0, pframe.length);
      var bodyFrame:Bytes = this.frame.makeBodyFrame(channel, content);
      output.writeBytes(bodyFrame, 0, bodyFrame.length);
      // translate into bytes wrapper
      var frame:Bytes = Bytes.ofData(output.getBytes().getData());
      // just send it
      this.sendBytes(frame);
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
      // just send it
      this.sendBytes(frame);
    } else {
      // just send it
      this.sendBytes(mframe);
      this.sendBytes(pframe);
    }
    // send content finally
    var written:Int = this.sendContent(channel, content);
    // return written bytes
    return written;
  }

  /**
   * Wrapper to send content
   * @param channel used channel id
   * @param content content bytes
   * @return Int
   */
  private function sendContent(channel:Int, content:Bytes):Int {
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
      // just send it
      this.sendBytes(bodyFrame);
      // increase written
      written += bodyFrame.length;
      // increase offset
      offset += maxBody;
    }
    return written;
  }

  /**
   * Shutdown everything
   * @param reason reason used for shutting down
   */
  public function shutdown(reason:String = "shutdown"):Void {
    // shutdown all channels
    for (i in this.channelMap) {
      i.shutdown();
    }
    // overwrite channels
    this.channelMap = new Map<Int, Channel>();
    // set close flag
    this.closed = true;
    // stop heartbeater
    this.stopHeartbeat();
    // finally close socket
    this.sock.close();
    // emit closed
    this.emit(EVENT_CLOSED, reason);
  }
}
