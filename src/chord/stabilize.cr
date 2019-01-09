require "../utils/timer"

class Chord
  # Polling interval for stabilization protocol
  SFREQ = 300.milliseconds

  def stabilize
    ticker = Timer.tick(SFREQ)
    quit_chan = Channel(Nil).new
    spawn do
      loop do
        select
        when ticker.chan.receive
          spawn query_predecessor
        when quit_chan.receive
          ticker.quit
          break
        end
      end
    end

    ->{ quit_chan.send nil }
  end

  # Ask successor node who its predecessor is
  private def query_predecessor
    # if successor = self.successor
    #   predecessor_request = PredecessorRequest.new
    #   @controller.dispatch(successor.ip, predecessor_request) do |response|
    #     if response.is_a?(Response::Predecessor)
    #       self.update_predecessor(response.predecessor, successor)
    #       self.notify_successor
    #     end
    #   end
    # end
    get_cmd = GetCommand.new "hello"
    packet = Message::ChordPacket.from_command(get_cmd, @local_hash)

    # @controller.connected_ips.each do |ip|
    #   @controller.dispatch ip, packet do
    #     puts "got response"
    #   end
    # end
  end
end