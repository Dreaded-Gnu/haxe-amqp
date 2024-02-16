package amqp.helper;

import haxe.io.BytesBuffer;
import haxe.Int64;

class BytesOutput extends haxe.io.BytesOutput {
  /**
   * Constructor
   */
  public function new() {
    super();
  }

  /**
   * Write int64 implementation
   * @param v
   */
  public function writeInt64(v:Int64):Void {
    if (bigEndian) {
      writeByte(v.high >>> 24);
      writeByte((v.high >> 16) & 0xFF);
      writeByte((v.high >> 8) & 0xFF);
      writeByte(v.high & 0xFF);
      writeByte(v.low >>> 24);
      writeByte((v.low >> 16) & 0xFF);
      writeByte((v.low >> 8) & 0xFF);
      writeByte(v.low & 0xFF);
    } else {
      writeByte(v.low & 0xFF);
      writeByte((v.low >> 8) & 0xFF);
      writeByte((v.low >> 16) & 0xFF);
      writeByte((v.low >> 24) & 0xFF);
      writeByte(v.high & 0xFF);
      writeByte((v.high >> 8) & 0xFF);
      writeByte((v.high >> 16) & 0xFF);
      writeByte(v.high >>> 24);
    }
  }

  /**
   * Flush override
   */
  override public function flush() {
    super.flush();
    #if flash
    b = new flash.utils.ByteArray();
    b.endian = flash.utils.Endian.LITTLE_ENDIAN;
    #else
    b = new BytesBuffer();
    #end
  }
}
