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
  end
end