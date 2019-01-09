require "./chord/*"
require "./chord/message/*"

class Chord
  @local_hash : {UInt64, String}
  @controller : Controller
  getter channels : Chord::ChannelBundle = Chord::ChannelBundle.instance
  getter store = Store.new

  class ConnectionError < Exception
  end

  def initialize(@local_ip : Socket::IPAddress, @seeds : Array(Socket::IPAddress))
    ip_str = @local_ip.to_s
    @local_hash = {CHash.digest(ip_str), ip_str}

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
      puts "Got net_stat #{net_stat}"
    else
      puts message.data
    end
  end

  # For testing purposes only
  def run
    ip_addrs = ["127.0.0.1:80", "0.0.0.0:12345"].map do |addr|
      Socket::IPAddress.parse "ip://#{addr}"
    end
  
    packet = Message::NetStat.new(ip_addrs)
  
    @controller.broadcast packet
    loop do
      @controller.read
    end
  end
end