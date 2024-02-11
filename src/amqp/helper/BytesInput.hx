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
    return try Int64.make(readInt32(), readInt32()) catch (e:Dynamic) throw new Eof();
  }
}
