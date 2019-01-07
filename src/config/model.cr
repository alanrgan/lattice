require "yaml"

struct Config
  struct Host
    include YAML::Serializable
    getter address : String
    getter port : Int32

    def to_ip
      Socket::IPAddress.parse "ip://#{address}:#{port}"
    end
  end
end