require "./controller/*"

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
end