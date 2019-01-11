require "../utils/timer"
require "../utils/ip"

class Chord
  def route(packet : Message::ChordPacket, *, key : String)
    key_hash = CHash.digest_pair(key)
    self.route(packet, key: key_hash)
  end

  def route(packet : Message::ChordPacket, *, key : NodeHash)
    response_chan = @channels.make_response_chan(packet.uid)

    self.route_once(packet, hash: key)

    awaiter = Timer::Awaiter(Message::ChordPacket).new response_chan
    awaiter.on_timeout do
      self.route_once(packet, hash: key)
    end

    awaiter
  end

  def route_once(packet : Message::ChordPacket, *, hash : StoreKey)
    predecessor = self.predecessor
    belongs_to_self = !predecessor.nil? && CHash.in_range?(hash, head: predecessor, tail: @local_hash)
    is_self = hash == @local_hash
    if belongs_to_self || is_self || !@finger_table.populated?
      @controller.dispatch(@local_ip, packet)
    elsif (successor = @finger_table.successor)
      if CHash.in_range?(hash, head: @local_hash, tail: successor)
        successor_ip = parse_ip(successor)
        # puts "Belongs to successor, routing #{packet} to #{successor_ip}"
        @controller.dispatch(successor_ip, packet)
      else
        closest_predecessor = @finger_table.lookup(hash)
        closest_predecessor_ip = parse_ip(closest_predecessor)

        forward_command = ForwardCommand.new(hash, packet)
        chord_packet = self.packet_from_command(forward_command)

        # puts "Forwarding from #{@local_hash} to node in FTable: #{closest_predecessor_ip}, packet: #{chord_packet}"
        @controller.dispatch(closest_predecessor_ip, chord_packet)
      end
    end
  end
end