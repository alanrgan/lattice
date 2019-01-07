require "./message"
require "./client"
require "./config"
require "./clap"

require "option_parser"

# TODO: Write documentation for `Lattice`
module Lattice
  VERSION = "0.1.0"

  def self.parse_opts
    opts = {"config_file" => "lattice.conf.yml"}
    OptionParser.parse! do |parser|
      parser.on("-c CONFIG_FILE", "--config=CONFIG_FILE", "Specifies the config file") { |file| opts["config_file"] = file }
      parser.invalid_option do |flag|
        STDERR.puts "ERROR: #{flag} is not a valid option."
        STDERR.puts parser
        exit(1)
      end
    end

    opts
  end

  opts = self.parse_opts
  config = Config.load opts["config_file"]
  
  local_ip = config.local_host.to_ip
  seeds = config.known_hosts.map &.to_ip

  client = Client.new(local_ip, seeds)

  spawn client.run

  loop do
    print "> "
    command = STDIN.gets

    case command
    when "quit"
      exit
    when .nil?
      STDERR.puts "error processing command"
    else
      begin
        command = Clap.parse(command)
        chord_message = Message::ChordPacket.from_command(
          command: command,
          uid: "abcdef",
          origin: {12345_u64, "localhost"}
        )
        message = chord_message.serialize
        packet = Message::Packet.deserialize_as Message::ChordPacket, message#_as Message::Type::ChordPacket, message
        puts packet.command
        # chord_packet = packet.as(Message::ChordPacket)
        # puts chord_message.command
      rescue ex : Clap::ParseError
        STDERR.puts ex
      end
    end

  end
end