require "../chord"

def parse_ip(ip : String)
  Socket::IPAddress.parse("ip://#{ip}")
end

def parse_ip(ip : Chord::NodeHash)
  parse_ip(ip[:value])
end