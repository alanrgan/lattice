require "./message"
require "./chord"

class Client
  CONN_TIMEOUT_SECONDS = 0.3

  @controller : Message::Controller
  @chord = Chord.new

  class ConnectionError < Exception
  end

  def initialize(@local_ip : Socket::IPAddress, seeds : Array(Socket::IPAddress))
    @controller = Message::Controller.new @local_ip
    @controller.on_message &->self.handle_message(Message::Base)
    @controller.on_failure { |ip| puts ip }

    spawn self.listen @local_ip.port

    #Attempt to connect to a seed
    seeds.each do |seed|
      begin
        socket = TCPSocket.new seed.address,
                               seed.port,
                               connect_timeout: CONN_TIMEOUT_SECONDS
      rescue ex
        break
      end

      self.add_connection seed, socket
      return
    end

    raise ConnectionError.new "Could not connect to a seed"
  end

  def add_connection(ip : Socket::IPAddress, socket : TCPSocket)
    @controller.add_connection ip, socket
  end

  def is_seed?
    true
  end

  def handle_message(message : Message::Base)
    case message.packet_type
    when .net_stat?
      net_stat = Message::Packet.deserialize_as Message::Type::NetStat, message.data
      puts "Got net_stat #{net_stat}"
    else
      puts message.data
    end
  end

  def handle_connection(client)
    @controller.add_connection client.remote_address, client

    if self.is_seed?
      # If the current node is a seed node, supply
      # the new node with an array of the current nodes in the network

      net_state = Message::NetStat.new @controller.connected_ips.to_a

      @controller.dispatch client.remote_address, net_state
    end
  end

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

  private def listen(port = 1280)
    server = TCPServer.new "0.0.0.0", port
    puts "Listening on port #{port}"
    while client = server.accept?
      spawn self.handle_connection(client)
    end
  end
end