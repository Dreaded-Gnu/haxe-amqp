package amqp.helper;

import haxe.io.BytesData;
import haxe.io.Encoding;

/**
 * Bytes extension class
 */
class Bytes extends haxe.io.Bytes {
  /**
   * Constructor
   * @param length length of bytes
   * @param b bytes data
   */
  public function new(length:Int, b:BytesData) {
    super(length, b);
  }

  /**
   * Set 16bit integer at position
   * @param pos position to use for setting
   * @param v value to set
   */
  public inline function setInt16(pos:Int, v:Int):Void {
    #if neko_v21
    untyped $sset16(b, pos, v, false);
    #else
    set(pos, v);
    set(pos + 1, v >> 8);
    #end
  }

  /**
   * Returns a new `Bytes` instance that contains a copy of `len` bytes of `this` instance, starting at index `pos`.
   * @param pos position to start at
   * @param len length of bytes
   * @return Bytes
   */
  override public function sub(pos:Int, len:Int):Bytes {
    var bytes:haxe.io.Bytes = super.sub(pos, len);
    return Bytes.ofData(bytes.getData());
  }

  /**
   * Allocate overwrite taken from bytes implementation
   * @param length amount of bytes to allocate
   * @return Bytes
   */
  public static function alloc(length:Int):Bytes {
    var bytes:haxe.io.Bytes = haxe.io.Bytes.alloc(length);
    return Bytes.ofData(bytes.getData());
  }

  /**
   * Generate bytes from string
   * @param s string to generate bytes form
   * @param encoding used encoding
   * @return bytes generated of string
   */
  public static function ofString(s:String, ?encoding:Encoding):Bytes {
    var bytes:haxe.io.Bytes = haxe.io.Bytes.ofString(s, encoding);
    return Bytes.ofData(bytes.getData());
  }

  /**
   * Generate bytes by data
   * @param b bytes data
   */
  public static function ofData(b:BytesData) {
    #if flash
    return new Bytes(b.length, b);
    #elseif neko
    return new Bytes(untyped __dollar__ssize(b), b);
    #elseif cs
    return new Bytes(b.Length, b);
    #else
    return new Bytes(b.length, b);
    #end
  }
}
