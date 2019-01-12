require "../utils/serializable"
require "../utils/ip"

class Chord
  def process_command(command : Command)
    case command
    when SetCommand
      packet = Message::ChordPacket.from_command command, @local_hash
      self.route(packet, key: command.key).await(5.seconds) do |response|
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
        self.route(packet, key: key).await(5.seconds) do |response|
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
    when OwnersCommand
      packet = Message::ChordPacket.from_command(command, @local_hash)
      self.route(packet, key: command.key).await(5.seconds) do |response|
        case inner_cmd = response.command
        when OwnersResponse
          puts (inner_cmd.nodes.map &.[:value]).join("\n")
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
        when OwnersCommand
          self.process_owners(command, packet.origin, packet.uid, &route_proc)
        when PredecessorRequest
          response = if predecessor = self.predecessor
            PredecessorResponse.new(parse_ip(predecessor))
          else
            PredecessorResponse.new
          end

          response_packet = response.as_response(packet.uid, @local_hash)
          @controller.dispatch(origin, response_packet)
        when PredNotification
          curr_predecessor = self.predecessor
          predecessor = command.pred_id
          @store.add_all(command.keys)

          entries = [] of Tuple(StoreKey, StoreEntry)

          if pred_of_pred = command.pred_of_pred
            entries = @store.entries_in_range(pred_of_pred, @local_hash)
            if successor = @finger_table.successor
              @store.clamp_to_range(pred_of_pred, successor)
            end
          end

          should_update = if curr_predecessor
            curr_pred_ip = parse_ip(curr_predecessor)
            pred_in_range = CHash.in_range?(predecessor, head: curr_predecessor, tail: @local_hash)
            pred_failed = !@controller.is_connected?(curr_pred_ip)
            pred_in_range || pred_failed
          else
            false
          end

          if !curr_predecessor || should_update
            self.set_predecessor(predecessor)
          end

          origin = parse_ip(packet.origin)
          pred_notif_response = PredNotifResponse.new(entries).as_response(packet, @local_hash)
          @controller.dispatch(origin, pred_notif_response)
        when ReplicaRequest
          @store.update({command.key, command.value})
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
      
      self.replicate(key_hash, @store[key_hash].not_nil!)
      set_response = SetResponse.new(true).as_response(uid, @local_hash)
      @controller.dispatch(origin, set_response)
    else
      block.call(key_hash)
    end
  end

  private def process_owners(command : Chord::OwnersCommand, origin : NodeHash, uid : String, &block : NodeHash ->)
    predecessor = self.predecessor
    successor = @finger_table.successor
    key = CHash.digest_pair(command.key)
    if predecessor && successor && CHash.in_range?(key, head: predecessor, tail: @local_hash)
      owners = [] of NodeHash

      if @store[key]
        owners << predecessor << @local_hash << successor
      end

      response = OwnersResponse.new(owners).as_response(uid, @local_hash)
      self.route(response, key: origin)
    else
      block.call(key)
    end
  end

end