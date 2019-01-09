require "../utils/timer"

class Chord
  def route(packet : Message::ChordPacket, *, hash : StoreKey)
    response_chan = @channels.make_response_chan(packet.uid)

    self.route_once(packet, hash: hash)

    awaiter = Timer::Awaiter(Message::Packet).new response_chan
    awaiter.on_timeout do
      self.route_once(packet, hash: hash)
    end

    awaiter
  end

  def route_once(packet : Message::ChordPacket, *, hash : StoreKey)
    puts "routing"
  end
end