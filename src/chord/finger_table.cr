class Chord::FingerTable
  @mux = Mutex.new
  @table = StaticArray(NodeHash, Chord::M).new({hash: 0_u64, value: ""})
  @size = 0_u8

  def initialize(@local_hash : NodeHash)
  end

  def size
    @mux.synchronize do
      @size
    end
  end

  def populate_with(ips : Array(Socket::IPAddress))
    hashed_ips = ips.map { |ip| CHash.digest_pair(ip.to_s) }
    hashed_ips.sort_by! { |hashed_ip| hashed_ip[:hash] }

    l = hashed_ips.size

    (0...Chord::M).each do |k|
      # take (@local_hash) + 2^k) % 2^M to achieve circularity property
      n = (@local_hash[:hash] + (1_u64 << k.to_u64)) & (1_u64 << (Chord::M-1))
      # Find the index of the first element whose hash is greater than or
      # equal to n
      idx = (0...l).bsearch { |i| hashed_ips[i][:hash] >= n }.not_nil!
      idx %= l
      
      # Do not allow a node to have itself in its finger table
      @table[k] = if hashed_ips[idx] == @local_hash
        hashed_ips[(idx + 1) % l]
      else
        hashed_ips[idx]
      end
    end
  end

  def insert(ip : Socket::IPAddress)
    self.insert(CHash.digest_pair(ip.to_s))
  end

  def insert(entry : NodeHash)
    @mux.synchronize do
      (0...Chord::M).each do |i|
        ft_hash = @table[i][:hash]
        n = (@local_hash[:hash] + (1 << i.to_u64)) & (1 << (Chord::M - 1))
        cond = CHash.hash_dist(n, ft_hash) < CHash.hash_dist(n, entry[:hash])
        unless ft_hash != 0 && cond
          @table[i] = entry
          @size += 1
        end
      end
    end
  end

  # Find the node whose hash is closest to that of the provided node, rounded down
  def lookup(node_id : NodeHash)
    if self.size == 0
      @local_hash
    else
      @mux.synchronize do
        (Chord::M-1...0).each do |i|
          node = @table[i]
          if node[:hash] == @local_hash[:hash]
            next
          elsif CHash.in_range?(node, head: @local_hash, tail: node_id)
            return node
          end
        end
      end

      # If the key is not on the current node and the hash does not
      # belong to any other node, then pass to successor
      self.successor.not_nil!
    end
  end

  def successor
    @mux.synchronize do
      @table[0] if @table[0][:hash] != 0
    end
  end

  def replace_all(key : String, replace_with : String)
    repl_hash = CHash.digest_pair(replace_with)
    @mux.synchronize do
      @table.each_with_index do |entry, i|
        if entry[1] == key
          @table[i] = repl_hash
        end
      end
    end
  end
end