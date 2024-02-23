package amqp;

import amqp.frame.type.DecodedFrame;
import amqp.frame.type.FrameHeaderType;
import amqp.frame.type.FrameMethodType;
import amqp.frame.type.FrameType;
import haxe.io.Input;
import amqp.helper.BytesInput;
import haxe.io.Encoding;
import haxe.io.BytesOutput;
import haxe.Exception;
import amqp.helper.Bytes;
import amqp.helper.protocol.Constant;
import amqp.helper.protocol.EncoderDecoderInfo;

class Frame {
  public static var PROTOCOL_HEADER(get, never):String;
  public static var HEARTBEAT(get, never):Dynamic;
  public static var HEARTBEAT_BUFFER(get, never):Bytes;

  /**
   * Constructor
   */
  public function new() {}

  /**
   * Getter for protocol header
   * @return String
   */
  private static function get_PROTOCOL_HEADER():String {
    return "AMQP" + String.fromCharCode(0) + String.fromCharCode(0) + String.fromCharCode(9) + String.fromCharCode(1);
  }

  /**
   * Getter for heartbeat
   * @return Dynamic
   */
  private static function get_HEARTBEAT():Dynamic {
    return {
      type: Constant.FRAME_HEARTBEAT,
      channel: 0,
    };
  }

  /**
   * Getter for heartbeat buffer
   * @return Bytes
   */
  private static function get_HEARTBEAT_BUFFER():Bytes {
    var bo:BytesOutput = new BytesOutput();
    bo.bigEndian = true;
    bo.writeByte(Constant.FRAME_HEARTBEAT);
    bo.writeInt16(0); // channel
    bo.writeInt32(0); // size
    bo.writeByte(Constant.FRAME_END);
    var bytes:haxe.io.Bytes = bo.getBytes();
    return new Bytes(bytes.length, bytes.getData());
  }

  /**
   * Helper to make body frame
   * @param channel
   * @param payload
   * @return Bytes
   */
  public function makeBodyFrame(channel:Int, payload:Bytes):Bytes {
    var bo:BytesOutput = new BytesOutput();
    bo.bigEndian = true;
    bo.writeByte(Constant.FRAME_BODY);
    bo.writeInt16(channel);
    bo.writeInt32(payload.length);
    bo.writeBytes(payload, 0, payload.length);
    bo.writeByte(Constant.FRAME_END);
    var bytes:haxe.io.Bytes = bo.getBytes();
    return new Bytes(bytes.length, bytes.getData());
  }

  /**
   * Helper to parse a frame
   * @param bin
   * @param max
   * @return Dynamic
   */
  public function parseFrame(bin:Input, max:Int):DecodedFrame {
    var type:Int = bin.readByte();
    var channel:Int = bin.readInt16();
    var size:Int = bin.readInt32();
    var buf:Bytes = Bytes.ofData(bin.readAll().getData());

    var fh:FrameType = {
      type: type,
      channel: channel,
      size: size,
      rest: buf,
    };
    var size:Int = fh.size;
    var rest:Bytes = fh.rest;
    if (size > max) {
      throw new Exception('Frame size exceeds ${max} with ${size}');
    } else if (rest.length > size) {
      if (rest.get(size) != Constant.FRAME_END) {
        throw new Exception('Invalid frame');
      }
      // read rest bytes if there is more than frame end
      var restByte:Bytes = null;
      if (rest.length + 1 > size) {
        restByte = rest.sub(size + 1, rest.length - size - 1);
      } else {
        restByte = Bytes.ofString("");
      }
      return {
        type: fh.type,
        channel: fh.channel,
        size: size,
        payload: rest.sub(0, size),
        rest: restByte,
      };
    }
    return null;
  }

  /**
   * Helper to decode a frame
   * @param frame
   * @return Dynamic
   */
  public function decodeFrame(frame:DecodedFrame):Dynamic {
    var payload:Bytes = frame.payload;
    var type:Int = frame.type;
    var bytes:BytesInput = new BytesInput(payload);
    bytes.bigEndian = true;
    switch (type) {
      case Constant.FRAME_METHOD:
        var idAndArgs:FrameMethodType = {
          id: bytes.readInt32(),
          args: payload.sub(4, payload.length - 4),
        };
        return {
          id: idAndArgs.id,
          channel: frame.channel,
          fields: EncoderDecoderInfo.decode(idAndArgs.id, new BytesInput(idAndArgs.args)),
        };
      case Constant.FRAME_HEADER:
        var parts:FrameHeaderType = {
          klass: bytes.readInt16(),
          _weight: bytes.readInt16(),
          size: bytes.readInt64(),
          flagsAndfields: payload.sub(12, payload.length - 12),
        };
        return {
          id: parts.klass,
          channel: frame.channel,
          size: parts.size,
          fields: EncoderDecoderInfo.decode(parts.klass, new BytesInput(parts.flagsAndfields)),
        };
      case Constant.FRAME_BODY:
        return {channel: frame.channel, content: frame.payload};
      case Constant.FRAME_HEARTBEAT:
        return HEARTBEAT;
      default:
        throw new Exception('Unknown frame type ' + frame.type);
    }
  }
}
