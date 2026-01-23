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
        name: payload.fetch("name", nil),
        fields: begin
          fields = payload.fetch("fields", nil).to_a
          raise ArgumentError, "fields must be a non-empty Array" if fields.empty?
          fields.map do |field|
            FieldPayload.new(
              name: field.fetch("name", nil),
              type: field.fetch("type", nil)
            )
          end
        end
      )
    end
  end
end
