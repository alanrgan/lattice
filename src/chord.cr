require "./chord/*"

class Chord
  @local_hash : {UInt64, String}
  getter store = Store.new

  def initialize(local_ip : Socket::IPAddress)
    ip_str = local_ip.to_s
    @local_hash = {CHash.digest(ip_str), ip_str}
  end
end