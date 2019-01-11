require "./chord/*"
require "./chord/message/*"

class Chord
  # M, where Chord supports 2^M possible keys
  M = 64

  alias NodeHash = StoreKey

  @local_hash : NodeHash
  @controller : Controller
  @finger_table : FingerTable
  @predecessor : NodeHash?
  @pred_mux = Mutex.new
  @is_seed : Bool?

  getter channels : ChannelBundle = ChannelBundle.instance
  getter store = Store.new

  class ConnectionError < Exception
  end

  def initialize(@local_ip : Socket::IPAddress, @seeds : Array(Socket::IPAddress))
    # Need to ignore port when evaluating hash
    ip_str = @local_ip.to_s
    @local_hash = {hash: CHash.digest(ip_str), value: ip_str}

    @finger_table = FingerTable.new @local_hash

    @controller = Controller.new @local_ip
    @controller.on_message &->self.handle_message(Message::Base)
    @controller.on_failure &->self.notify_failure(Socket::IPAddress)

    # Spawn IO fibers
    spawn self.handle_incoming_messages
    spawn self.listen @local_ip.port
    
    # Attempt to connect to a seed
    self.dial_seeds unless self.is_seed?

    # Start stabilization protocol
    quit_stabilization = self.stabilize
  end

  def notify_failure(ip : Socket::IPAddress)
    hashed_ip = CHash.digest_pair(ip.to_s)
    successor = self.successor_of(ip)
    @finger_table.replace_all(hashed_ip, successor)
  end

  def handle_message(message : Message::Base)
    # puts "got message: #{message}"
    case message.packet_type
    when .net_stat?
      net_stat = Message::Packet.deserialize_as Message::NetStat, message.data
      @finger_table.populate_with(net_stat.ip_addresses)
      @controller.dial(net_stat.ip_addresses)
    when .chord_packet?
      chord_packet = Message::Packet.deserialize_as Message::ChordPacket, message.data
      @channels.send(chord_packet)
    end
  end

  def predecessor
    @pred_mux.synchronize do
      @predecessor
    end
  end

  def set_predecessor(pred : NodeHash)
    @pred_mux.synchronize do
      @predecessor = pred
    end
  end

  def successor_of(ip : Socket::IPAddress)
    hashed_ips = @controller.connected_ips.map { |addr| CHash.digest_pair(addr.to_s) } << @local_hash
    hashed_ips.sort_by! &.[:hash]
    node = CHash.digest_pair(ip.to_s)
    
    hashed_ips.each do |other_node|
      if other_node[:hash] > node[:hash]
        return other_node
      end
    end

    hashed_ips[0]
  end

end