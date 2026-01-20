# typed: true

require "sorbet-runtime"
require_relative "../../app"
require_relative "attribute_payload"

module App::Controllers::Entities
  class CreateEntityRequest < T::Struct
    extend T::Sig

    const :attributes, T::Array[AttributePayload]

    sig { params(payload: T::Hash[String, T.untyped]).returns(CreateEntityRequest) }
    def self.from_hash(payload)
      new(
        attributes: payload.fetch("attributes").map do |attribute|
          AttributePayload.new(
            name: attribute.fetch("name"),
            value: attribute.fetch("value")
          )
        end
      )
    end
  end
end
