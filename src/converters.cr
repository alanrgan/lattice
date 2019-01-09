require "json"

require "./chord/message"

class TypeConverter
  def self.to_json(value : Chord::Message::Type, json : JSON::Builder)
    json.string(value.to_s)
  end

  def self.from_json(value : JSON::PullParser)
    Chord::Message::Type.parse(value.read_string)
  end
end

class ArrayConverter(T, K)
  def self.from_json(value : JSON::PullParser)
    values = [] of K
    value.read_array do
      values << T.from_json(value)
    end
    values
  end

  def self.to_json(value : Array(K), json : JSON::Builder)
    json.array do
      value.each do |item|
        T.to_json item, json
      end
    end
  end
end

class AddrConverter
  def self.from_json(value : JSON::PullParser)
    Socket::IPAddress.parse "ip://#{value.read_string}"
  end
  
  def self.to_json(value : Socket::IPAddress, json : JSON::Builder)
    json.string(value.to_s)
  end
end

class SocketArrayConverter < ArrayConverter(AddrConverter, Socket::IPAddress)
end