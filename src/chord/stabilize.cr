require "../utils/timer"
require "../utils/ip"

class Chord
  # Polling interval for stabilization protocol
  SFREQ = 300.milliseconds
  @contacted = Set(String).new
  @contacted_mux = Mutex.new

  private def contacted?(ip : String)
    @contacted_mux.synchronize do
      @contacted.includes?(ip)
    end
  end

  private def mark_as_contacted(ip : String)
    @contacted_mux.synchronize do
      @contacted.add(ip)
    end
  end

  # Run the Chord stabilization protocol for nodes joining and failing
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
    # puts "querying predecessor"
    if successor = @finger_table.successor
      successor_ip = parse_ip(successor)
      pred_request = PredecessorRequest.new
      pred_packet = self.packet_from_command(pred_request)
      # puts "Sending pred request to #{successor_ip}"
      @controller.dispatch(successor_ip, pred_packet) do |response|
        command = response.command
        if command.is_a?(PredecessorResponse)
          # puts "got pred response #{command}"
          pred_hash = CHash.digest_pair(command.predecessor.to_s) if command.predecessor
          self.update_successor(pred_hash, successor.not_nil!)
          self.notify_successor
        end
      end
    end
  end

  private def update_successor(predecessor : NodeHash?, successor : NodeHash)
    if predecessor.nil?
    elsif predecessor != @local_hash && CHash.in_range?(predecessor, head: @local_hash, tail: successor)
      # puts "parsing predecessor #{predecessor}"
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

  private def notify_successor
    if successor = @finger_table.successor
      successor_ip = parse_ip(successor)
      predecessor = self.predecessor
      keys = [] of Tuple(StoreKey, StoreEntry)

      have_contacted = self.contacted?(successor_ip.to_s)

      if predecessor && !have_contacted
        keys = @store.entries_in_range(predecessor, successor)
      end

      pred_notification = PredNotification.new(@local_hash, predecessor, keys)
      packet = self.packet_from_command(pred_notification)
      # puts "Notifying successor, #{successor_ip} with packet: #{packet}"

      @controller.dispatch(successor_ip, packet) do |response|
        case inner_cmd = response.command
        when PredNotifResponse
          if !have_contacted
            @store.add_all(inner_cmd.keys)
          end
        end
      end

      self.mark_as_contacted(successor_ip.to_s)
    end
  end
end