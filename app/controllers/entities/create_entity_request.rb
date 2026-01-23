# typed: true

require "dry-struct"
require_relative "../../app"
require_relative "../../types"
require_relative "attribute_payload"

module App::Controllers::Entities
  class CreateEntityRequest < Dry::Struct
    transform_keys(&:to_sym)

    attribute :attributes, App::Types::Array.of(AttributePayload).constrained(min_size: 1)

    alias_method :attributes_hash, :attributes

    def attributes
      self[:attributes]
    end

    def self.from_hash(payload)
      new(payload)
    end
  end
end
