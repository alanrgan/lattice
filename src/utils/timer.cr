module Timer
  extend self
  
  private class Ticker
    getter chan = Channel(Nil).new(1)
    @quit = Channel(Nil).new(1)

    def initialize(interval : Time::Span)
      spawn do
        loop do
          unless @quit.full?
            sleep interval
            @chan.send nil
          else
            break
          end
        end
      end
    end

    def get
      @chan.receive
    end

    def quit
      @quit.send nil
    end
  end

  class Awaiter(T)
    @on_timeout : Proc(Nil)?

    def initialize(@chan : Channel(T))
    end

    def await(time, &block : T ->)
      spawn do
        loop do
          select
          when value = @chan.receive
            block.call(value.not_nil!)
            break
          when Timer.after(3.seconds).receive
            if errback = @on_timeout
              errback.call
            end
          end
        end
      end
    end

    def on_timeout(&block)
      @on_timeout = block
    end
  end

  def after(n : Time::Span)
    channel = Channel(Nil).new
    spawn do
      sleep n
      channel.send nil
    end
    channel
  end

  def tick(interval : Time::Span)
    Ticker.new interval
  end
end