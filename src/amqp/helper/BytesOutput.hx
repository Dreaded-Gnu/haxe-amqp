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
    b.addInt64(v);
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
