class Chord
  alias StoreKey = {hash: UInt64, value: String}
  alias StoreEntry = Tuple(String, UInt64)

  class Store
    @mux = Mutex.new
    @kvmap = Hash(StoreKey, StoreEntry).new

    def [](key : StoreKey)
      @mux.synchronize do
        @kvmap[key]?
      end
    end

    def [](key : String)
      key_hash = CHash.digest_pair(key)
      self[key_hash]
    end

    def []=(key : StoreKey, value : StoreEntry)
      self[key] = value[0]
    end
    
    def []=(key : StoreKey, value : String)
      @mux.lock
      unless @kvmap.has_key?(key)
        @kvmap[key] = {value, 0_u64}
        @mux.unlock
      else
        current_count = @kvmap[key][1]
        @mux.unlock
        self.update({key, {value, current_count + 1}})
      end
    end

    def []=(key : String, value : String)
      key_hash = CHash.digest_pair(key)
      self[key_hash] = value
    end

    def each_key(&block : StoreKey ->)
      @kvmap.each_key(&block)
    end

    def update(entry : Tuple(StoreKey, StoreEntry))
      @mux.synchronize do
        key, value = entry
        own_entry = @kvmap[key]?
        if !own_entry
          @kvmap[key] = value
        elsif own_entry[1] <= value[1] && own_entry[0] != value[0]
          @kvmap[key] = {value[0], value[1]+1}
        end
      end
    end

    def entries_in_range(head : NodeHash, tail : NodeHash)
      entries = [] of Tuple(StoreKey, StoreEntry)
      @mux.synchronize do
        @kvmap.each do |key, entry|
          if CHash.in_range?(key, head: head, tail: tail)
            entries << {key, entry}
          end
        end
      end
      entries
    end

    def clip_range(head : NodeHash, tail : NodeHash)
      @mux.synchronize do
        @kvmap.delete_if { |key, _| CHash.in_range?(key, head: head, tail: tail) }
      end
    end

    def clamp_to_range(head : NodeHash, tail : NodeHash)
      unless @prev_clamp_range == {head, tail}
        @prev_clamp_range = {head, tail}
        self.clip_range(head, tail)
      end
    end

    def add_all(entries : Array({StoreKey, StoreEntry}))
      @mux.synchronize do  
        entries.each do |entry|
          own_entry = @kvmap[entry[0]]
          if !own_entry
            @kvmap[entry[0]] = entry[1]
          # Only allow more recent updates by checking counter
          # on the entry
          elsif own_entry[1] <= entry[1][1]
            # Verify that key has been updated
            if own_entry[0] != entry[1][0]
              @kvmap[entry[0]] = {entry[1][0], entry[1][1] + 1}
            end
          end
        end
      end
    end

  end

end