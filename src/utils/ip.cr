require "../chord"

PORT = 1280

def parse_ip(ip : String)
  addr = Socket::IPAddress.parse("ip://#{ip}")
  addr = Socket::IPAddress.new(addr.address, PORT)
end

def parse_ip(ip : Chord::NodeHash)
  parse_ip(ip[:value])
end