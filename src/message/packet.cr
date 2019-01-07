require "json"
require "../utils/serializable"

module Message
  extend self

  enum Type
    Base
    NetStat
    ConnRequest
    ChordPacket

    def as_kind
      case self
      when .base? then Message::Base
      when .net_stat? then Message::NetStat
      when .conn_request? then Message::ConnectionRequest
      when .chord_packet? then Message::ChordPacket
      end
    end
  end

  class SerializationError < Exception
  end

  abstract struct Packet < Serializable(Type)
    include JSON::Serializable
  end
end