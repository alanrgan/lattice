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
      {hash, key}
    end
  end
end
