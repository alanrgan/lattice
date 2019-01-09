require "../utils/serializable"

class Chord
  def process_command(command : Command)
    case command
    when SetCommand
      key_hash = CHash.digest_pair(command.key)
      packet = Message::ChordPacket.from_command command, @local_hash
      self.route(packet, hash: key_hash).await(5) do |response|
        puts response
      end
    when GetCommand
      key_hash = CHash.digest_pair(command.key)
      # If found locally, return the value
      if value = @store[key_hash]
        puts "Found: #{value[0]}"
      # otherwise route according to Chord protocol
      else
        packet = Message::ChordPacket.from_command command, @local_hash
        self.route(packet, hash: key_hash).await(5) do |response|
          puts "response"
        end
      end
    when ListLocalCommand
      @store.each_key do |key|
        puts key[1]
      end
      puts "END LIST_LOCAL"
    end
  end

  private def handle_incoming_messages
    loop do
      packet = @channels.receive
      spawn self.process_chord_packet(packet)
    end
  end

  private def process_chord_packet(packet : Message::ChordPacket)
    @channels.put_response(packet) do
      begin
        case command = packet.command
        when Chord::GetCommand
          self.process_get(command)
        when Chord::SetCommand
          self.process_set(command)
        when Chord::ListLocalCommand
          self.process_list_local(command)
        end
      rescue Serializable::SerializationError | ArgumentError
        STDERR.puts "Could not deserialize ChordMessage with type: #{packet.type}"
      end
    end
  end

  ## Individual Chord command handlers

  private def process_get(command : Chord::GetCommand)
  
  end

  private def process_set(command : Chord::SetCommand)
    key_hash = CHash.digest_pair(command.key)
    @store[command.key] = command.value
  end

  private def process_list_local(command : Chord::ListLocalCommand)

  end
end