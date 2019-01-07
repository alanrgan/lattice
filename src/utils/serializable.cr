require "json"

abstract struct Serializable(T)
  include JSON::Serializable

  class SerializationError < Exception
  end

  private class Repr
    JSON.mapping(
      type: String,
      data: String
    )
  end

  abstract def kind : Symbol

  def serialize
    JSON.build do |json|
      json.object do
        json.field "type", self.kind
        json.field "data", self.to_json
      end
    end
  end

  def self.deserialize_as(type : T, value : String)
    deserialized_repr = Repr.from_json value

    if deserialized_repr.type === type.to_s.underscore && (packet_class = type.as_kind)
      packet_class.from_json deserialized_repr.data
    else
      raise SerializationError.new(
        "Mismatched types: \
        Expected #{type.to_s.underscore}, received #{deserialized_repr.type}"
      )
    end
  end

  def self.deserialize_as(klass : K.class, value : String) forall K
    deserialized_repr = Repr.from_json value

    if deserialized_repr.type === klass.type.to_s.underscore
      klass.from_json deserialized_repr.data
    else
      raise SerializationError.new(
        "Mismatched kinds: \
        Expected #{klass.type.to_s}, received #{deserialized_repr.type}"
      )
    end
  end
end