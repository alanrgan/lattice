require "../utils/ip"

class Chord
  def replicate(key : StoreKey, value : StoreEntry)
    replicate_command = ReplicaRequest.new(key, value)
    packet = Message::ChordPacket.from_command(replicate_command, @local_hash)
    self.replica_set.each do |ip|
      @controller.dispatch(ip, packet)
    end
  end

  private def replica_set
    dest_nodes = [] of Socket::IPAddress
    if predecessor = self.predecessor
      dest_nodes << parse_ip(predecessor)
    end
    
    if successor = @finger_table.successor
      dest_nodes << parse_ip(successor)
    end
    
    dest_nodes
  end
end