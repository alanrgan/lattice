require "./controller/*"
require "../../utils/ip"

class Chord::Controller
  @fail_mux = Mutex.new
  @fail_channel = Channel(Socket::IPAddress).new
  @out_channel = Channel(Message::Packet).new
  @connected_ips = Set(Socket::IPAddress).new

  @dispatcher = Dispatcher.new

  def initialize(@local_ip : Socket::IPAddress)
    spawn self.handle_failure
    spawn self.handle_outgoing_messages
  end

  def connected_ips
    @fail_mux.synchronize do
      @connected_ips
    end
  end

  def dial(ips : Array(Socket::IPAddress))
    connected_ips = self.connected_ips
    ips.each do |ip|
      unless connected_ips.includes?(ip)
        self.dial(ip) { |ex| puts(ex) }
      end
    end
  end

  def dial(ip : Socket::IPAddress)
    self.dial(ip) { |ex| raise ex }
  end

  def dial(ip : Socket::IPAddress)
    begin
      socket = TCPSocket.new ip.address,
                             ip.port, 
                             connect_timeout: Chord::CONN_TIMEOUT_SECONDS
    rescue ex
      yield ex
      return
    end
    self.add_connection(ip, socket)
  end

  def add_connection(addr, socket)
    # puts "Adding connection #{addr}, #{socket}"
    @fail_mux.synchronize do
      @connected_ips.add addr
      @dispatcher.add_connection addr, socket
    end
    # puts "Handling incoming messages from #{addr}"
    spawn self.handle_incoming_messages(addr, socket)
  end

  def is_connected?(ip : Socket::IPAddress)
    @fail_mux.synchronize do
      @connected_ips.includes? ip
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
end