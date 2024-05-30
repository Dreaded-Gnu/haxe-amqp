package amqp;

import haxe.io.Encoding;
import amqp.helper.BytesInput;
import amqp.helper.BytesOutput;
import haxe.Json;
import haxe.Exception;
import amqp.helper.Bytes;

/**
 * Some static helper for encoding and decoding
 */
class Codec {
  /**
   * Helper to encode field value
   * @param buffer buffer to write encoded field value to
   * @param value value to encode
   */
  private static function EncodeFieldValue(buffer:BytesOutput, value:Dynamic):Void {
    var type = Type.typeof(value);
    var t:String;
    var val:Dynamic = value;
    // A trapdoor for specifying a type, e.g., timestamp
    if (value && type == TObject && Reflect.hasField(value, '!')) {
      val = value.value;
      type = Reflect.field(value, '!');
    }

    // If it's a JS number, we'll have to guess what type to encode it
    // as.
    if (type == TInt || type == TFloat) {
      // Making assumptions about the kind of number (floating point
      // v integer, signed, unsigned, size) desired is dangerous in
      // general; however, in practice RabbitMQ uses only
      // longstrings and unsigned integers in its arguments, and
      // other clients generally conflate number types anyway. So
      // the only distinction we care about is floating point vs
      // integers, preferring integers since those can be promoted
      // if necessary. If floating point is required, we may as well
      // use double precision.
      if (type == TFloat) {
        t = 'double';
      } else { // only signed values are used in tables by
        // RabbitMQ. It *used* to (< v3.3.0) treat the byte 'b'
        // type as unsigned, but most clients (and the spec)
        // think it's signed, and now RabbitMQ does too.
        if (val < 128 && val >= -128) {
          t = 'byte';
        } else if (val >= -0x8000 && val < 0x8000) {
          t = 'short';
        } else if (val >= -0x80000000 && val < 0x80000000) {
          t = 'int';
        } else {
          t = 'long';
        }
      }
    } else if (Std.isOfType(val, String)) {
      t = 'string';
    } else if (type == TObject) {
      t = 'object';
    } else if (type == TBool) {
      t = 'boolean';
    } else {
      t = 'unknown';
    }

    function tag(t:String) {
      buffer.writeByte(t.charCodeAt(0));
    }

    switch (t) {
      case 'string': // no shortstr in field tables
        var len = cast(val, String).length;
        tag('S');
        buffer.writeInt32(len);
        buffer.writeString(cast(val, String), Encoding.UTF8);
      case 'object':
        if (val == null) {
          tag('V');
        } else if (Std.isOfType(val, Array)) {
          tag('A');
          var start:Int = buffer.length;
          // leave space for array size
          buffer.writeInt32(0);
          for (v in cast(val, Array<Dynamic>)) {
            EncodeFieldValue(buffer, v);
          }
          var size:Int = buffer.length - start;
          // hacky push in size
          var sizeOutput:BytesOutput = new BytesOutput();
          sizeOutput.bigEndian = true;
          sizeOutput.writeInt32(size - 4);
          var bytes:haxe.io.Bytes = buffer.getBytes();
          bytes.blit(start, sizeOutput.getBytes(), 0, 4);
          // generate new buffer with written bytes
          buffer.flush();
          buffer.writeBytes(bytes, 0, bytes.length);
        } else if (Std.isOfType(val, Bytes)) {
          tag('x');
          var b:Bytes = cast(val, Bytes);
          buffer.writeInt32(b.length);
          buffer.writeBytes(b, 0, b.length);
        } else {
          tag('F');
          var bytes:Bytes = EncodeTable(buffer, val);
          buffer.flush();
          buffer.writeBytes(bytes, 0, bytes.length);
        }
      case 'boolean':
        tag('t');
        buffer.writeByte(cast(val, Bool) ? 1 : 0);
      // These are the types that are either guessed above, or
      // explicitly given using the {'!': type} notation.
      case 'double', 'float64':
        tag('d');
        buffer.writeDouble(val);
      case 'byte', 'int8':
        tag('b');
        buffer.writeByte(val);
      case 'short', 'int16':
        tag('s');
        buffer.writeInt16(val);
      case 'int', 'int32':
        tag('I');
        buffer.writeInt32(val);
      case 'long', 'int64':
        tag('l');
        buffer.writeInt64(val);
      // Now for exotic types, those can _only_ be denoted by using
      // `{'!': type, value: val}
      case 'timestamp':
        tag('T');
        buffer.writeInt64(val);
      case 'float':
        tag('f');
        buffer.writeFloat(val);
      case 'decimal':
        tag('D');
        if (Reflect.hasField(val, 'places') && Reflect.hasField(val, 'digits') && val.places >= 0 && val.places < 256) {
          buffer.writeByte(val.places);
          buffer.writeInt32(val.digits);
        } else {
          throw new Exception("Decimal value must be {'places': 0..255, 'digits': uint32}, got " + Json.stringify(val));
        }
      default:
        throw new Exception('Unknown type to encode: $type');
    }
  }

  /**
   * Helper to encode table
   * @param bytes buffer to write table to
   * @param val table to write
   * @return encoded bytes
   */
  public static function EncodeTable(bytes:BytesOutput, val:Dynamic):Bytes {
    var start:Int = bytes.length;
    bytes.writeInt32(0); // leave space for table length
    for (key in Reflect.fields(val)) {
      // get value
      var value:Dynamic = Reflect.field(val, key);
      // skip null
      /// FIXME: DON'T SEEMS RIGHT TO SKIP NULL VALUES
      /*if (value == null) {
        continue;
      }*/
      // get key length
      var len:Int = key.length;
      // push back key length and key itself
      bytes.writeByte(len);
      bytes.writeString(key, Encoding.UTF8);
      // Encode field value
      EncodeFieldValue(bytes, value);
    }
    var size:Int = bytes.length;
    // hacky push size into correct order
    var sizeOutput:BytesOutput = new BytesOutput();
    sizeOutput.bigEndian = true;
    sizeOutput.writeInt32(size - start - 4);
    var b:haxe.io.Bytes = bytes.getBytes();
    b.blit(start, sizeOutput.getBytes(), 0, 4);
    // return bytes as string
    return Bytes.ofData(b.getData());
  }

  /**
   * Helper to decode fields
   * @param buffer buffer to read from
   * @return Decoded field information
   */
  public static function DecodeFields(buffer:Bytes):Dynamic {
    var fields:Dynamic = {};
    var size:Int = buffer.length;
    var len:Int;
    var key:String;
    var val:Dynamic = null;

    var bytesInput:BytesInput = new BytesInput(buffer);
    bytesInput.bigEndian = true;

    function decodeFieldValue():Void {
      var tag:Int = bytesInput.readByte();
      switch (tag) {
        case 'b'.code:
          val = bytesInput.readByte();
        case 'S'.code:
          len = bytesInput.readInt32();
          val = bytesInput.readString(len);
        case 'I'.code:
          val = bytesInput.readInt32();
        case 'D'.code: // only positive decimals, apparently.
          var places:Int = bytesInput.readByte();
          var digits = bytesInput.readInt32();
          val = {'!': 'decimal', value: {places: places, digits: digits}};
        case 'T'.code:
          val = bytesInput.readInt64();
          val = {'!': 'timestamp', value: val};
        case 'F'.code:
          len = bytesInput.readInt32();
          var b:haxe.io.Bytes = haxe.io.Bytes.alloc(len);
          bytesInput.readBytes(b, 0, len);
          val = DecodeFields(Bytes.ofData(b.getData()));
        case 'A'.code:
          len = bytesInput.readInt32();
          var vals = [];
          while (bytesInput.position < bytesInput.position + len) {
            decodeFieldValue();
            vals.push(val);
          }
          val = vals;
        case 'd'.code:
          val = bytesInput.readDouble();
        case 'f'.code:
          val = bytesInput.readFloat();
        case 'l'.code:
          val = bytesInput.readInt64();
        case 's'.code:
          val = bytesInput.readInt16();
        case 't'.code:
          val = bytesInput.readByte() != 0;
        case 'V'.code:
          val = null;
        case 'x'.code:
          len = bytesInput.readInt32();
          var b:Bytes = Bytes.alloc(len);
          bytesInput.readBytes(b, 0, len);
          val = b;
        default:
          throw new Exception('Unexpected type tag "$tag"');
      }
    }

    while (bytesInput.position < size) {
      len = bytesInput.readByte();
      key = bytesInput.readString(len);
      decodeFieldValue();
      Reflect.setField(fields, key, val);
    }
    return fields;
  }
}
