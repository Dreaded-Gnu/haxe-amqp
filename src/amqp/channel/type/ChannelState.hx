package amqp.channel.type;

enum abstract ChannelState(Int) {
  var ChannelStateInit = 0;
  var ChannelStateOpen = 1;
  var ChannelStateClosed = 2;
}
