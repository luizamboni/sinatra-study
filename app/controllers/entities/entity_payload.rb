# typed: true

require "sorbet-runtime"
require_relative "../../app"
require_relative "attribute_payload"

module App::Controllers::Entities
  class EntityPayload < T::Struct
    const :schema, String
    const :attributes, T::Array[AttributePayload]
  end
end
