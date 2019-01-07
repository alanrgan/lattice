class Chord
  def process_command(command : Command)
    case command
    when SetCommand
      puts command.value
    when GetCommand
      puts command.key
    when ListLocalCommand
      puts "listing local"
    end
  end
end