class Message::Dispatcher
  # Mutex to synchronize IP-Connection access
  @mux = Mutex.new
  @ip_to_connection = Hash(Socket::IPAddress, Connection).new

  private struct Connection
    getter mux
    getter socket : TCPSocket

    def initialize(@socket)
      @mux = Mutex.new
    end
  end

  def add_connection(addr, socket : TCPSocket)
    @mux.synchronize do
      @ip_to_connection[addr] = Connection.new socket
    end
  end

  def send_or(addr, packet : Message::Packet)
    begin
      conn = @ip_to_connection[addr]
      conn.mux.synchronize do
        base_packet = Message::Base.new packet
        conn.socket.puts base_packet.serialize
      end
    rescue
      yield
    end
  end
end