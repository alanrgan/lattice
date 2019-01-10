class Chord
  class ChannelBundle
    @@instance = new
    @response_channels = Hash(String, Channel(Message::ChordPacket)).new
    @incoming_chan = Channel(Message::ChordPacket).new
    @mux = Mutex.new

    private def initialize
    end

    def send(packet : Message::ChordPacket)
      @incoming_chan.send(packet)
    end

    def receive
      @incoming_chan.receive
    end

    def await(uid)
      @response_channels[uid].receive
    end

    def make_response_chan(uid : String)
      @mux.synchronize do
        chan = Channel(Message::ChordPacket).new
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
          yield response
        end
      end
    end

    def put_response?(response : Message::ChordPacket)
      self.put_response(response) { |_| nil }
    end
    
    def self.instance
      @@instance
    end
  end
end