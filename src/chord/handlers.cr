require "../message"

class Chord
  def process_command(command : Command)
    case command
    when SetCommand
      key_hash = CHash.digest_pair(command.key)
      packet = Message::ChordPacket.from_command command, @local_hash
      # self.route(packet) do |response|
        
      # end
      puts "Packet is #{packet}"
      @store[command.key] = command.value
    when GetCommand
      key_hash = CHash.digest_pair(command.key)
      if value = @store[key_hash]
        puts "Found: #{value[0]}"
      else
        puts "not found"
      end
    when ListLocalCommand
      @store.each_key do |key|
        puts key[1]
      end
      puts "END LIST_LOCAL"
    end
  end
end