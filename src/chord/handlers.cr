require "../utils/serializable"
require "../utils/ip"

class Chord
  def process_command(command : Command)
    case command
    when SetCommand
      packet = Message::ChordPacket.from_command command, @local_hash
      self.route(packet, key: command.key).await(5) do |response|
        case inner_response = response.command
        when SetResponse
          if inner_response.success
            puts "SET OK"
          else
            puts "SET ERROR"
          end
        end
      end
    when GetCommand
      key = command.key
      # If found locally, return the value
      if value = @store[key]
        puts "Found: #{value[0]}"
      # otherwise route according to Chord protocol
      else
        packet = Message::ChordPacket.from_command command, @local_hash
        self.route(packet, key: key).await(5) do |response|
          case inner_cmd = response.command
          when GetResponse
            if value = inner_cmd.value
              puts "Found #{value}"
            else
              puts "Not found"
            end
          end
        end
      end
    when ListLocalCommand
      @store.each_key do |key|
        puts key[:value]
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
    origin = parse_ip(packet.origin)

    @channels.put_response(packet) do
      route_proc = ->(key_hash : NodeHash){ self.route(packet, key: key_hash) }
      begin
        case command = packet.command
        when GetCommand
          self.process_get(command, packet.origin, packet.uid, &route_proc)
        when SetCommand
          self.process_set(command, origin, packet.uid, &route_proc)
        when ListLocalCommand
          self.process_list_local(command)
        when PredecessorRequest
          response = if predecessor = self.predecessor
            PredecessorResponse.new(parse_ip(predecessor))
          else
            PredecessorResponse.new
          end

          response_packet = self.packet_from_command(response)
          @controller.dispatch(origin, response_packet)
        when ForwardCommand
          self.route(command.packet, key: command.key)
        end
      rescue Serializable::SerializationError | ArgumentError
        STDERR.puts "Could not deserialize ChordMessage with type: #{packet.type}"
      end
    end
  end

  ## Individual Chord command handlers

  private def process_get(command : Chord::GetCommand, origin : NodeHash, uid : String, &block : NodeHash ->)
    predecessor = self.predecessor
    key_hash = CHash.digest_pair(command.key)

    if entry = @store[key_hash]
      get_response = GetResponse.new(entry[0]).as_response(uid, @local_hash)
      self.route(get_response, key: origin)
    elsif predecessor && CHash.in_range?(key_hash, head: predecessor, tail: @local_hash)
      get_response = GetResponse.new.as_response(uid, @local_hash)
      self.route(get_response, key: origin)
    else
      block.call(key_hash)
    end
  end

  private def process_set(command : Chord::SetCommand, origin : Socket::IPAddress, uid : String, &block : NodeHash ->)
    predecessor = self.predecessor
    key_hash = CHash.digest_pair(command.key)
    if predecessor.nil? || CHash.in_range?(key_hash, head: predecessor, tail: @local_hash)
      @store[key_hash] = command.value
      set_response = SetResponse.new(true).as_response(uid, @local_hash)
      @controller.dispatch(origin, set_response)
    else
      block.call(key_hash)
    end
  end

  private def process_list_local(command : Chord::ListLocalCommand)

  end
end