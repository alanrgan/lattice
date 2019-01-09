require "json"
require "../utils/serializable"

class Chord
  enum CommandType
    Set
    Get
    ListLocal

    def as_kind
      case self
      when .set? then SetCommand
      when .get? then GetCommand
      when .list_local? then ListLocalCommand
      end
    end

    def is_response?
      ## TODO
      false
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
end