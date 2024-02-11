package amqp;

import haxe.Json;
import haxe.io.Input;
import amqp.helper.BytesInput;
import haxe.Int64;
import haxe.Int32;
import haxe.io.Encoding;
import haxe.io.BytesOutput;
import haxe.Exception;
import amqp.helper.Bytes;
import amqp.helper.protocol.Constant;
import amqp.helper.protocol.EncoderDecoderInfo;
import amqp.Codec;

typedef FrameType = {
  var type:Int;
  var channel:Int;
  var size:Int32;
  var rest:Bytes;
}

typedef FrameHeaderType = {
  var klass:Int;
  var _weight:Int;
  var size:Int64;
  var flagsAndfields:Bytes;
}

typedef FrameMethodType = {
  var id:Int32;
  var args:Bytes;
}

class Frame {
  public static var PROTOCOL_HEADER:String = "AMQP" + String.fromCharCode(0) + String.fromCharCode(0) + String.fromCharCode(9) + String.fromCharCode(1);
  public static var HEARTBEAT:Dynamic = {channel: 0,};
  public static var HEARTBEAT_BUFFER(get, never):Bytes;

  private static function get_HEARTBEAT_BUFFER():Bytes {
    var bytes:BytesOutput = new BytesOutput();
    bytes.bigEndian = true;
    bytes.writeInt32(Constant.FRAME_HEARTBEAT);
    bytes.writeInt32(0);
    bytes.writeInt16(0);
    bytes.writeInt32(Constant.FRAME_END);
    return new Bytes(bytes.getBytes().length, bytes.getBytes().getData());
  }

  public static function makeBodyFrame(channel:Int, payload:Bytes):Bytes {
    var bytes:BytesOutput = new BytesOutput();
    bytes.bigEndian = true;
    bytes.writeInt32(Constant.FRAME_BODY);
    bytes.writeInt16(channel);
    bytes.writeInt32(payload.length);
    bytes.writeString(payload.toString(), Encoding.UTF8);
    bytes.writeInt32(Constant.FRAME_END);
    return new Bytes(bytes.getBytes().length, bytes.getBytes().getData());
  }

  public static function parseFrame(bin:Input, max:Int):Dynamic {
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
      throw new Exception('Frame size exceeds frame max');
    } else if (rest.length > size) {
      if (rest.get(size) != Constant.FRAME_END) {
        throw new Exception('Invalid frame');
      }
      return {
        type: fh.type,
        channel: fh.channel,
        size: size,
        payload: rest.sub(0, size),
        rest: rest.sub(size, rest.length - size),
      };
    }
    return null;
  }

  public static function decodeFrame(frame:Dynamic):Dynamic {
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
