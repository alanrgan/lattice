class Client
  @chord = Chord.new

  def process_command(command : Chord::Command)
    @chord.process_command command
  end
end
    