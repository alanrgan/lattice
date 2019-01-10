require "digest"

class Chord
  module CHash
    extend self

    private def to_u64(byte_arr)
      val = 0_u64
      (1..8).each do |n|
        val |= (byte_arr[8-n]).to_u64 << (8*(n-1))
      end
      val
    end
    
    # Hash a string into a UInt64
    def digest(key : String)
      to_u64(Digest::SHA1.digest(key))
    end

    def digest_pair(key : String)
      hash = digest(key)
      {hash: hash, value: key}
    end

    # 'a' is the start hash and 'b' is the end
    # (distance from 'a' to 'b', clockwise)
    # for example:
    #   for Chord::M = 64,
    #   hash_dist(15, 20) < hash_dist(15, 12)
    #   i.e. 20 is closer to 15 than 12 is to 15
    #   to take into account the circularity of the chord hash space
    def hash_dist(a : UInt64, b : UInt64)
      if b < a
        (1 << (Chord::M-1))+b-a+1
      else
        (b-a) & (1 << (M-1))
      end
    end

    def hash_dist(a : NodeHash, b : NodeHash)
      hash_dist(a[:hash], b[:hash])
    end

    def in_range?(node : NodeHash, *, head : NodeHash, tail : NodeHash)
      interval_dist = hash_dist(head, tail)
      head_to_node_dist = hash_dist(head, node)
      head_to_node_dist != 0 && head_to_node_dist <= interval_dist
    end
  end
end
