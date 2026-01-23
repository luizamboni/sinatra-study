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
        attributes: begin
          attrs = payload.fetch("attributes", nil).to_a
          raise ArgumentError, "attributes must be a non-empty Array" if attrs.empty?
          attrs.map do |attribute|
            AttributePayload.new(
              name: attribute.fetch("name", nil),
              value: attribute.fetch("value", nil)
            )
          end
        end
      )
    end
  end
end
