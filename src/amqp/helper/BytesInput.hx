package amqp.helper;

import haxe.io.Eof;
import haxe.Int64;
import amqp.helper.Bytes;

class BytesInput extends haxe.io.BytesInput {
  /**
   * Constructor
   * @param b
   * @param pos
   * @param len
   */
  public function new(b:Bytes, ?pos:Int, ?len:Int) {
    super(b, pos, len);
  }

  /**
   * Helper to read int 64
   * @return Int64
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
