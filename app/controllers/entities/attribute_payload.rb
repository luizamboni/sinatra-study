# typed: true

require "dry-struct"
require_relative "../../app"
require_relative "../../types"

module App::Controllers::Entities
  class AttributePayload < Dry::Struct
    transform_keys(&:to_sym)

    attribute :name, App::Types::String
    attribute :value, App::Types::String | App::Types::Integer | App::Types::Float | App::Types::Bool
  end
end
