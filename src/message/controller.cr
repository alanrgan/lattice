class Message::Controller
  @fail_mux = Mutex.new
  @fail_channel = Channel(Socket::IPAddress).new
  @out_channel = Channel(Message::Packet).new
  getter connected_ips = Set(Socket::IPAddress).new

  @dispatcher = Message::Dispatcher.new

  def initialize(@local_ip : Socket::IPAddress)
    spawn self.handle_failure
    spawn self.handle_outgoing_messages
  end

  def add_connection(addr, socket)
    @fail_mux.synchronize do
      @connected_ips.add addr
      @dispatcher.add_connection addr, socket
    end
    spawn self.handle_incoming_messages(addr, socket)
  end

  def is_connected?(ip : Socket::IPAddress)
    @connected_ips.includes? ip
  end

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

  def on_failure(&block : Socket::IPAddress ->)
    @failure_handler = block
  end

  def on_message(&block : Message::Base ->)
    @message_callback = block
  end

  def read
    chan = Channel(Int32).new
    chan.receive
  end

  private def mark_as_failed(ip)
    @fail_mux.synchronize do
      @connected_ips.delete ip
      @fail_channel.send ip
    end
  end

  private def handle_failure
    loop do
      fail_ip = @fail_channel.receive
      if failure_handler = @failure_handler
        failure_handler.call(fail_ip)
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
          base_packet = Message::Packet.deserialize_as Message::Type::Base, message
        rescue ex
          puts ex
          self.mark_as_failed ip
          return
        end

        callback.call(base_packet) if base_packet.is_a?(Message::Base)
      end
    end
  end

end