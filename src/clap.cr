require "./chord/command"

module Clap
  class ParseError < Exception
  end

  # Parse a command from an input string and return the corresponding
  # Command object upon success. Raises a ParseError if it cannot parse the input.
  def self.parse(input : String)
    argv = input.strip.split(" ")
    unless argv.size == 0
      case argv[0]
      when "SET"
        self.expect(argv, 2, exc: "Usage: SET <key>, <value>", op: :gthan) do
          value = argv[2..-1].join(" ")
          Chord::SetCommand.new(key: argv[1], value: value)
          # {
          #   "type" => "SET",
          #   "key" => argv[1],
          #   "value" => value
          # }
        end
      when "GET"
        self.expect(argv, 2, exc: "Usage: GET <key>") do
          Chord::GetCommand.new(key: argv[1])
          # {"type" => "GET", "key" => argv[1]}
        end
      when "LIST_LOCAL"
        self.expect(argv, 1, exc: "Usage: LIST_LOCAL") do
          Chord::ListLocalCommand.new
          # {"type" => "LIST_LOCAL"}
        end
      else
        raise ParseError.new("Invalid command #{argv[0]}\n \
                              Available commands are SET, GET, and LIST_LOCAL")
      end
    else
      raise ParseError.new("Cannot have empty input.")
    end
  end

  # This method verifies the size of argv. If successful, control is yielded to the provided block
  private def self.expect(argv, nargs, *, exc : String?, op = :eq)
    case op
    when :eq
      op_proc = ->(a : Int32, b : Int32){ a == b }
    when :lthan
      op_proc = ->(a : Int32, b : Int32){ a < b }
    when :gthan
      op_proc = ->(a : Int32, b : Int32){ a > b }
    when :neq
      op_proc = ->(a : Int32, b : Int32){ a != b }
    else
      raise "Invalid operator provided: #{op}. \
      Expected one of :eq, :lthan, :gthan or :neq"
    end

    if op_proc && op_proc.call(argv.size, nargs)
      yield
    else
      raise ParseError.new(exc || "Expected argument of size #{nargs}, got #{argv.size}")
    end
  end
end