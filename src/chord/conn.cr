require "../utils/ip"

class Chord
  CONN_TIMEOUT_SECONDS = 1

  def dial_seeds
    connected_seed = nil

    # Cycle through seeds 5 times with timeout until
    # the node manages to connect to one
    10.times do
      @seeds.each do |seed|
        begin
          @controller.dial(seed)
        rescue
          next
        else
          connected_seed = seed
          break
        end
      end
      
      if connected_seed
        return
      end
    end

    raise ConnectionError.new "Could not connect to a seed"
  end

  private def listen(port = 1280)
    server = TCPServer.new "0.0.0.0", port
    puts "Listening on port #{port}"
    while client = server.accept?
      spawn self.handle_connection(client)
    end
  end

  def handle_connection(client)
    remote_ip = Socket::IPAddress.new(client.remote_address.address, PORT)
    @controller.add_connection remote_ip, client

    @finger_table.insert(remote_ip)

    if self.is_seed?
      # If the current node is a seed node, supply
      # the new node with an array of the current nodes in the network
      ips_on_network = @controller.connected_ips.to_a << @local_ip

      net_state = Message::NetStat.new ips_on_network
      
      @controller.dispatch remote_ip, net_state
    end
  end

  def is_seed?
    @is_seed = unless @is_seed.nil?
      @is_seed
    else
      @seeds.includes?(@local_ip)
    end
  end
end