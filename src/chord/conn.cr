class Chord
  CONN_TIMEOUT_SECONDS = 0.3

  def dial_seeds
    @seeds.each do |seed|
      begin
        @controller.dial(seed)
      rescue
        next
      else
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
    @controller.add_connection client.remote_address, client

    @finger_table.insert(client.remote_address)

    if self.is_seed?
      # If the current node is a seed node, supply
      # the new node with an array of the current nodes in the network
      ips_on_network = @controller.connected_ips.to_a << @local_ip

      net_state = Message::NetStat.new ips_on_network
      
      @controller.dispatch client.remote_address, net_state
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