require "json"
require "socket"
require "uuid"

require "./*"
require "../../converters"
require "../../utils/serializable"
require "../command"

module Chord::Message
  struct Base < Packet
    Serializable.with_kind :base

    @[JSON::Field(converter: TypeConverter)]
    getter packet_type : Type
    getter data
    
    def initialize(@packet_type : Type, @data : String)
    end

    def initialize(other : Packet)
      @packet_type = Message::Type.parse(other.kind.to_s)
      @data = other.serialize
    end
  end

  struct ConnectionRequest < Packet
    Serializable.with_kind :conn_request

    @[JSON::Field(key: "address", converter: AddrConverter)]
    getter addr : Socket::IPAddress

    def initialize(@addr : Socket::IPAddress)
    end

    def initialize(addr : String)
      @addr = Socket::IPAddress.parse "ip://#{addr}"
    end
  end

  struct NetStat < Packet
    Serializable.with_kind :net_stat

    @[JSON::Field(converter: SocketArrayConverter)]
    @ip_addresses = [] of Socket::IPAddress

    def initialize(@ip_addresses : Array(Socket::IPAddress))
    end
  end

  struct ChordPacket < Packet
    Serializable.with_kind :chord_packet
  
    getter? is_response = false
    getter uid
    getter type

    def initialize(@type : String, @uid : String, @origin : {UInt64, String}, @command : String, *, @is_response = false)
    end


    def self.from_command(command : Chord::Command, origin : {UInt64, String})
      uid = UUID.random.to_s
      new(command.kind.to_s, uid, origin, command.serialize)
    end

    def command
      command_type = Chord::CommandType.parse(@type)
      Chord::Command.deserialize_as command_type, @command
    end
  end
end