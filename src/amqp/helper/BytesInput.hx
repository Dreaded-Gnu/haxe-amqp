package amqp.helper;

import haxe.Int64;
import amqp.helper.Bytes;

/**
 * Bytes input extension
 */
@:dox(hide) class BytesInput extends haxe.io.BytesInput {
  /**
   * Constructor
   * @param b bytes object
   * @param pos position
   * @param len length
   */
  public function new(b:Bytes, ?pos:Int, ?len:Int) {
    super(b, pos, len);
  }

  /**
   * Helper to read int 64
   * @return 64bit integer
   */
  public function readInt64():Int64 {
    var ch1:Int = readByte();
    var ch2:Int = readByte();
    var ch3:Int = readByte();
    var ch4:Int = readByte();
    var ch5:Int = readByte();
    var ch6:Int = readByte();
    var ch7:Int = readByte();
    var ch8:Int = readByte();
    if (bigEndian) {
      return Int64.make(ch4 | (ch3 << 8) | (ch2 << 16) | (ch1 << 24), ch8 | (ch7 << 8) | (ch6 << 16) | (ch5 << 24));
    } else {
      return Int64.make(ch5 | (ch6 << 8) | (ch7 << 16) | (ch8 << 24), ch1 | (ch2 << 8) | (ch3 << 16) | (ch4 << 24));
    }
  }
}
