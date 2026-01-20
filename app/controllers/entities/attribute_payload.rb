# typed: true

require "sorbet-runtime"
require_relative "../../app"

module App::Controllers::Entities
  class AttributePayload < T::Struct
    const :name, String
    const :value, T.any(String, Integer, Float, Numeric, T::Boolean)
  end
end
