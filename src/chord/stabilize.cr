require "../utils/timer"
require "../utils/ip"

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
    if successor = @finger_table.successor
      successor_ip = parse_ip(successor)
      pred_request = PredecessorRequest.new
      pred_packet = self.packet_from_command(pred_request)
      @controller.dispatch(successor_ip, pred_packet) do |response|
        command = response.command
        if command.is_a?(PredecessorResponse)
          pred_hash = CHash.digest_pair(command.predecessor.to_s)
          self.update_successor(pred_hash, successor.not_nil!)
          # self.notify_successor
        end
      end
    end
  end

  private def update_successor(predecessor : NodeHash?, successor : NodeHash)
    if predecessor.nil?
    elsif predecessor != @local_hash && CHash.in_range?(predecessor, head: @local_hash, tail: successor)
      pred_ip = parse_ip(predecessor)

      unless @controller.is_connected?(pred_ip)
        begin
          @controller.dial(pred_ip)
        rescue
        else
          @finger_table.insert(predecessor)
        end
      end
    end
  end
end