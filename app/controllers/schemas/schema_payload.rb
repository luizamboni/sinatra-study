# typed: true

require "sorbet-runtime"
require_relative "../../app"
require_relative "field_payload"

module App::Controllers::Schemas
  class SchemaPayload < T::Struct
    const :name, String
    const :fields, T::Array[FieldPayload]
  end
end
