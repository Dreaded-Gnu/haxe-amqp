package amqp;

class Heartbeat {
  private var interval:Int;
  private var checkSend:() -> Bool;
  private var checkReceive:() -> Bool;

  public function new(interval:Int, checkSend:() -> Bool, checkReceive:() -> Bool) {
    this.interval = interval;
    this.checkSend = checkSend;
    this.checkReceive = checkReceive;
  }
}
