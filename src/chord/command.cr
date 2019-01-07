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
  end

  abstract struct Command < Serializable(CommandType)
    include JSON::Serializable
  end

  struct SetCommand < Command
    def initialize(@key : String, @value : String)
    end

    def kind
      :set
    end

    def self.type
      :set
    end
  end

  struct GetCommand < Command
    def initialize(@key : String)
    end

    def kind
      :get
    end

    def self.type
      :get
    end
  end

  struct ListLocalCommand < Command
    def initialize
    end

    def kind
      :list_local
    end

    def self.type
      :list_local
    end
  end
end