# typed: true

require "sorbet-runtime"
require_relative "../../app"
require_relative "field_payload"

module App::Controllers::Schemas
  class CreateSchemaRequest < T::Struct
    extend T::Sig

    const :name, String
    const :fields, T::Array[FieldPayload]

    sig { params(payload: T::Hash[String, T.untyped]).returns(CreateSchemaRequest) }
    def self.from_hash(payload)
      new(
        name: payload.fetch("name"),
        fields: payload.fetch("fields").map do |field|
          FieldPayload.new(
            name: field.fetch("name"),
            type: field.fetch("type")
          )
        end
      )
    end
  end
end
