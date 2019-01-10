require "json"
require "../converters"
require "../utils/serializable"

class Chord
  enum CommandType
    Set
    Get
    ListLocal
    PredRequest
    PredResponse

    def as_kind
      case self
      when .set? then SetCommand
      when .get? then GetCommand
      when .list_local? then ListLocalCommand
      when .pred_request? then PredecessorRequest
      when .pred_response? then PredecessorResponse
      end
    end

    def is_response?
      self.pred_response?
    end
  end

  abstract struct Command < Serializable(CommandType)
    include JSON::Serializable
  end

  struct SetCommand < Command
    Serializable.with_kind :set
   
    getter key
    getter value : String

    def initialize(@key : String, @value : String)
    end
  end

  struct GetCommand < Command
    Serializable.with_kind :get
    
    getter key

    def initialize(@key : String)
    end
  end

  struct ListLocalCommand < Command
    Serializable.with_kind :list_local

    def initialize
    end
  end

  struct PredecessorRequest < Command
    Serializable.with_kind :pred_request

    def initialize
    end
  end

  struct PredecessorResponse < Command
    Serializable.with_kind :pred_response

    @[JSON::Field(converter: AddrConverter)]
    getter predecessor : Socket::IPAddress

    def initialize(@predecessor : Socket::IPAddress)
    end
  end

  def packet_from_command(command : Command)
    Message::ChordPacket.from_command(command, @local_hash)
  end
end