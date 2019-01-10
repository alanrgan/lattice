require "../utils/timer"

class Chord
  def route(packet : Message::ChordPacket, *, key : String)
    response_chan = @channels.make_response_chan(packet.uid)
    key_hash = CHash.digest_pair(key)

    self.route_once(packet, hash: key_hash)

    awaiter = Timer::Awaiter(Message::ChordPacket).new response_chan
    awaiter.on_timeout do
      self.route_once(packet, hash: key_hash)
    end

    awaiter
  end

  def route_once(packet : Message::ChordPacket, *, hash : StoreKey)
    puts "routing"
  end
end