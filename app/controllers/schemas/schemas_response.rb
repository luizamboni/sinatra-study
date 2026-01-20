# typed: true

require "sorbet-runtime"
require_relative "../../app"
require_relative "schema_payload"

module App::Controllers::Schemas
  class SchemasResponse < T::Struct
    const :schemas, T::Array[SchemaPayload]
  end
end
