require "./chord/*"
require "./chord/message/*"

class Chord
  # M, where Chord supports 2^M possible keys
  M = 64

  alias NodeHash = StoreKey

  @local_hash : NodeHash
  @controller : Controller
  @finger_table : FingerTable

  getter channels : ChannelBundle = ChannelBundle.instance
  getter store = Store.new

  class ConnectionError < Exception
  end

  def initialize(@local_ip : Socket::IPAddress, @seeds : Array(Socket::IPAddress))
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
    self.dial_seeds

    # Start stabilization protocol
    quit_stabilization = self.stabilize
  end

  def notify_failure(ip : Socket::IPAddress)
    puts "ip #{ip} failed"
  end

  def handle_message(message : Message::Base)
    case message.packet_type
    when .net_stat?
      net_stat = Message::Packet.deserialize_as Message::NetStat, message.data
      @finger_table.populate_with(net_stat.ip_addresses)
      @controller.dial(net_stat.ip_addresses)
    when .chord_packet?
      chord_packet = Message::Packet.deserialize_as Message::ChordPacket, message.data
      puts "got chord packet, #{chord_packet}"
      @channels.send(chord_packet)
      # # puts message.data
    end
  end

  # For testing purposes only
  def run
    # ip_addrs = ["127.0.0.1:80", "0.0.0.0:12345"].map do |addr|
    #   Socket::IPAddress.parse "ip://#{addr}"
    # end
  
    # packet = Message::NetStat.new(ip_addrs)
    get_cmd = Chord::GetCommand.new "hello"
    packet = Message::ChordPacket.from_command(get_cmd, @local_hash)

    response_packet = Message::ChordPacket.new("get_response", packet.uid, @local_hash, "hi", is_response: true)

    @controller.connected_ips.each do |ip|
      @controller.dispatch ip, packet do |response|
        puts "Got response: #{response}"
      end
      @controller.dispatch ip, response_packet
    end
    # @controller.broadcast packet
    loop do
      @controller.read
    end
  end
end