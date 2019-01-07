require "json"
require "socket"
require "./*"
require "../converters"
require "../utils/serializable"
require "../chord/command"

module Message
  struct Base < Packet
    @[JSON::Field(converter: TypeConverter)]
    getter packet_type : Type
    getter data
    
    def initialize(@packet_type : Type, @data : String)
    end

    def initialize(other : Packet)
      @packet_type = Message::Type.parse(other.kind.to_s)
      @data = other.serialize
    end

    def kind
      :base
    end

    def self.type
      :base
    end
  end

  struct ConnectionRequest < Packet
    @[JSON::Field(key: "address", converter: AddrConverter)]
    getter addr : Socket::IPAddress

    def initialize(@addr : Socket::IPAddress)
    end

    def initialize(addr : String)
      @addr = Socket::IPAddress.parse "ip://#{addr}"
    end

    def kind
      :conn_request
    end

    def self.type
      :conn_request
    end
  end

  struct NetStat < Packet
    @[JSON::Field(converter: SocketArrayConverter)]
    @ip_addresses = [] of Socket::IPAddress

    def initialize(@ip_addresses : Array(Socket::IPAddress))
    end

    def kind
      :net_stat
    end

    def self.type
      :net_stat
    end
  end

  struct ChordPacket < Packet
    property is_response = false
    
    def initialize(@type : String, @uid : String, @origin : {UInt64, String}, @command : String)
    end

    def kind
      :chord_packet
    end

    def self.from_command(command : Chord::Command, uid : String, origin : {UInt64, String})
      new(command.kind.to_s, uid, origin, command.serialize)
    end

    def self.type
      :chord_packet
    end

    def command
      command_type = Chord::CommandType.parse(@type)
      case command_type
      when .set? then Chord::Command.deserialize_as Chord::SetCommand, @command
      when .get? then Chord::Command.deserialize_as Chord::GetCommand, @command
      when .list_local? then Chord::Command.deserialize_as Chord::ListLocalCommand, @command
      end
      # Chord::Command.deserialize_as command_type, @command
    end
  end
end