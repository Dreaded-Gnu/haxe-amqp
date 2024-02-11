package amqp;

import haxe.Exception;
import haxe.Json;
import sys.net.Host;
import sys.thread.Thread;
import hxdispatch.Dispatcher;
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
class Connection extends Dispatcher<String> {
  public var config(default, null):Config;
  public var sock(default, null):sys.net.Socket;
  public var output(default, null):BytesOutput;

  private var serverProperties:Dynamic;
  private var channelMax:Int;
  private var frameMax:Int;
  private var heartbeat:Int;

  /**
   * Constructor
   * @param config
   */
  public function new(config:Config) {
    super();
    this.config = config;
    this.output = new BytesOutput();
    this.register("connected");
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
  public static function socketReader() {
    var connection:Connection = cast Thread.readMessage(true);
    while (true) {
      try {
        var byte:Int = connection.sock.input.readByte();
        // trace('Reading data: ${byte}');
        connection.output.writeByte(byte);
      } catch (e:Dynamic) {
        if (Std.isOfType(e, haxe.io.Eof) || e == haxe.io.Eof) {
          trace('Eof, reader thread exiting...');
          return;
        } else if (e == haxe.io.Error.Blocked) {
          // trace( 'Blocked!' );
        } else {
          trace('Uncaught: ${e}'); // throw e;
        }
      }
    }
  }

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
   */
  public function connect():Void {
    // generate socket
    if (this.config.isSecure) {
      this.sock = new sys.ssl.Socket();
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

    // get opening frame content
    var openFrameData:TOpenFrame = openFrames();

    var thread:Thread = Thread.create(socketReader);
    thread.sendMessage(this);

    // send protocol header
    var b:Bytes = Bytes.ofString(Frame.PROTOCOL_HEADER);
    this.sock.output.writeFullBytes(b, 0, b.length);

    // read data, decode frame and check for connection start was sent
    var frame:Dynamic = this.readData();
    if (frame.id != EncoderDecoderInfo.ConnectionStart) {
      throw new Exception('Expected ${EncoderDecoderInfo.info(EncoderDecoderInfo.ConnectionStart).name}');
    }

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
    sendMethod(0, EncoderDecoderInfo.ConnectionStartOk, openFrameData.startOk);

    // decode frame and check for tune
    frame = this.readData();
    if (frame.id != EncoderDecoderInfo.ConnectionTune) {
      throw new Exception('Expected ${EncoderDecoderInfo.info(EncoderDecoderInfo.ConnectionTune).name}');
    }
    // adjust openFrameData tune ok according to return from server
    openFrameData.tuneOk.frameMax = negotiate(frame.fields.frameMax, openFrameData.tuneOk.frameMax);
    openFrameData.tuneOk.channelMax = negotiate(frame.fields.channelMax, openFrameData.tuneOk.channelMax);
    openFrameData.tuneOk.heartbeat = negotiate(frame.fields.heartbeat, openFrameData.tuneOk.heartbeat);
    // send tune ok
    sendMethod(0, EncoderDecoderInfo.ConnectionTuneOk, openFrameData.tuneOk);

    // send open message
    sendMethod(0, EncoderDecoderInfo.ConnectionOpen, openFrameData.open);

    // decode frame and check for connection open ok
    frame = this.readData();
    if (frame.id != EncoderDecoderInfo.ConnectionOpenOk) {
      throw new Exception('Expected ${EncoderDecoderInfo.info(EncoderDecoderInfo.ConnectionOpenOk).name}');
    }
    // store channel max, frame max and heartbeat
    this.channelMax = openFrameData.tuneOk.channelMax;
    this.frameMax = openFrameData.tuneOk.frameMax;
    this.heartbeat = openFrameData.tuneOk.heartbeat;

    this.trigger("connected", "Successfully connected!");
  }

  /**
   * Read data provided by thread
   * @param output
   * @return Dynamic
   */
  private function readData():Dynamic {
    while (true) {
      // get bytes from output buffer filled by thread
      var bytes:Bytes = Bytes.ofData(this.output.getBytes().getData());
      // flush out
      this.output.flush();
      // handle no data
      if (bytes.length == 0) {
        Sys.sleep(1);
        continue;
      }
      // create bytes input accessor with big endian
      var input:BytesInput = new BytesInput(bytes);
      input.bigEndian = true;
      // parse frame
      var parsedFrame = Frame.parseFrame(input, Constant.FRAME_MIN_SIZE);
      // return decoded frame
      return Frame.decodeFrame(parsedFrame);
    }
  }

  /**
   * Helper method to send a method
   * @param channel
   * @param method
   * @param fields
   */
  private function sendMethod(channel:Int, method:Int, fields:Dynamic):Void {
    // encode method
    var frame:Bytes = EncoderDecoderInfo.encodeMethod(method, channel, fields);
    // write to network
    this.sock.output.writeFullBytes(frame, 0, frame.length);
    // flush socket output
    this.sock.output.flush();
  }
}
