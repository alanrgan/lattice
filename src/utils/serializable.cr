require "json"

abstract struct Serializable(T)
  include JSON::Serializable

  class SerializationError < Exception
  end

  private class Repr
    JSON.mapping(
      kind: String,
      data: String
    )
  end

  abstract def kind : Symbol

  def serialize
    JSON.build do |json|
      json.object do
        json.field "kind", self.kind
        json.field "data", self.to_json
      end
    end
  end

  def self.deserialize_as(type : T, value : String)
    deserialized_repr = Repr.from_json value

    if deserialized_repr.kind === type.to_s.underscore && (packet_class = type.as_kind)
      packet_class.from_json deserialized_repr.data
    else
      raise SerializationError.new(
        "Mismatched kinds: \
        Expected #{deserialized_repr.kind}, received #{type.to_s.underscore}"
      )
    end
  end
end