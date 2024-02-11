import utest.Runner;
import utest.ui.Report;
import utest.Assert;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.crypto.BaseCode;
import amqp.connection.Config;
import amqp.helper.protocol.Constant;
import amqp.helper.protocol.EncoderDecoderInfo;
import amqp.helper.BytesInput;
import amqp.helper.Bytes;
import amqp.Frame;
import amqp.Codec;
import amqp.Heartbeat;
import amqp.Connection;

class Test {
  public static function main() {
    utest.UTest.run([
      new ConnectTest()]);
  }
}

class ConnectTest extends utest.Test {
  public function testMin() {
  }
}
