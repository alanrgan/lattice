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
    PredNotification
    SetResponse
    GetResponse
    ReplicaRequest
    Forward

    def as_kind
      case self
      when .set? then SetCommand
      when .get? then GetCommand
      when .list_local? then ListLocalCommand
      when .pred_request? then PredecessorRequest
      when .pred_response? then PredecessorResponse
      when .forward? then ForwardCommand
      when .set_response? then Chord::SetResponse
      when .get_response? then Chord::GetResponse
      when .pred_notification? then Chord::PredNotification
      when .replica_request? then Chord::ReplicaRequest
      end
    end

    def is_response?
      self.pred_response?
    end
  end

  abstract struct Command < Serializable(CommandType)
    include JSON::Serializable

    def as_response(other : Message::ChordPacket, local_hash : NodeHash)
      self.as_response(other.uid, local_hash)
    end

    def as_response(uid : String, local_hash : NodeHash)
      Message::ChordPacket.new(self.kind.to_s, uid, local_hash, self.serialize, is_response: true)
    end
  end

  struct SetCommand < Command
    Serializable.with_kind :set
   
    getter key
    getter value : String

    def initialize(@key : String, @value : String)
    end
  end
  
  struct SetResponse < Command
    Serializable.with_kind :set_response

    getter success
    
    def initialize(@success : Bool)
    end
  end

  struct GetCommand < Command
    Serializable.with_kind :get
    
    getter key

    def initialize(@key : String)
    end
  end

  struct GetResponse < Command
    Serializable.with_kind :get_response

    getter value : String?

    def initialize
    end

    def initialize(@value : String)
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
    getter predecessor : Socket::IPAddress?

    def initialize
    end

    def initialize(@predecessor : Socket::IPAddress)
    end
  end

  struct PredNotification < Command
    Serializable.with_kind :pred_notification
  end

  struct ReplicaRequest < Command
    Serializable.with_kind :replica_request
  end

  struct ForwardCommand < Command
    Serializable.with_kind :forward
    getter packet
    getter key

    def initialize(@key : NodeHash, @packet : Message::ChordPacket)
    end
  end

  def packet_from_command(command : Command)
    Message::ChordPacket.from_command(command, @local_hash)
  end
end