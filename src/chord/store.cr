class Chord
  alias StoreKey = {UInt64, String}
  alias Entry = {String, UInt64}

  class Store < Hash(StoreKey, Entry)
    @mux = Mutex.new

    def [](key : StoreKey)
      @mux.synchronize do
        begin
          super
        rescue KeyError
          nil
        end
      end
    end

    def [](key : String)
      key_hash = CHash.digest_pair(key)
      self[key_hash]
    end

    def []=(key : StoreKey, value : Entry)
      @mux.synchronize do
        super
      end
    end

    def []=(key : String, value : String)
      key_hash = CHash.digest_pair(key)
      self[key_hash] = {value, 0_u64}
    end
  end
end