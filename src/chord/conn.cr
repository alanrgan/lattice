class Chord
  CONN_TIMEOUT_SECONDS = 0.3

  def dial_seeds
    @seeds.each do |seed|
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

  private def add_connection(ip : Socket::IPAddress, socket : TCPSocket)
    @controller.add_connection ip, socket
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

    if self.is_seed?
      # If the current node is a seed node, supply
      # the new node with an array of the current nodes in the network

      net_state = Message::NetStat.new @controller.connected_ips.to_a

      @controller.dispatch client.remote_address, net_state
    end
  end

  def is_seed?
    true
  end
end