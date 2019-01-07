class Message::Controller
  def broadcast(packet : Message::Packet)
    @out_channel.send packet
    if callback = @message_callback
      callback.call Message::Base.new(packet)
    end
  end

  def dispatch(ip : Socket::IPAddress, packet : Message::Packet)
    @fail_mux.synchronize do
      if !@connected_ips.includes? ip
        return
      end
    end

    if ip == @local_ip
    else
      @dispatcher.send_or(ip, packet) do
        self.mark_as_failed ip
      end
    end
  end
  
  private def handle_outgoing_messages
    loop do
      message = @out_channel.receive
      @connected_ips.each do |ip|
        self.dispatch ip, message
      end
    end
  end

  private def handle_incoming_messages(ip : Socket::IPAddress, socket : TCPSocket)
    loop do
      message = socket.gets

      # Handle socket disconnect
      if message.nil?
        puts "Failed"
        self.mark_as_failed ip
        return
      elsif callback = @message_callback
        begin
          base_packet = Message::Packet.deserialize_as Message::Base, message
        rescue ex
          puts ex
          self.mark_as_failed ip
          return
        end

        callback.call(base_packet)
      end
    end
  end
end