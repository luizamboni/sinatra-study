# typed: true

require "dry-struct"
require_relative "../../app"
require_relative "../../types"
require_relative "field_payload"

module App::Controllers::Schemas
  class CreateSchemaRequest < Dry::Struct
    transform_keys(&:to_sym)

    attribute :name, App::Types::String
    attribute :fields, App::Types::Array.of(FieldPayload).constrained(min_size: 1)

    def self.from_hash(payload)
      new(payload)
    end
  end
end
