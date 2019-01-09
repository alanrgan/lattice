# require "../message"

class Chord
  class ChannelBundle
    @@instance = new
    @response_channels = Hash(String, Channel(Message::Packet)).new
    @incoming_chan = Channel(Message::ChordPacket).new
    @mux = Mutex.new

    private def initialize
    end

    def receive
      @incoming_chan.receive
    end

    def make_response_chan(uid : String)
      @mux.synchronize do
        chan = Channel(Message::Packet).new
        @response_channels[uid] = chan
        chan
      end
    end

    def put_response(response : Message::ChordPacket)
      uid = response.uid
      @mux.synchronize do
        if response.is_response? && (chan = @response_channels[uid]?)
          chan.send(response)
        else
          yield
        end
      end
    end

    def put_response?(response : Message::ChordPacket)
      self.put_response(response) { nil }
    end
    
    def self.instance
      @@instance
    end
  end
end