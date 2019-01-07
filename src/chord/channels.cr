require "../message"

class Chord
  class ChannelBundle
    @response_channels = Hash(String, Channel(Message::Packet)).new
    @incoming_chan = Channel(Message::Packet).new

    private def initialize
    end

    def self.instance
      @@instance ||= new
    end
  end
end