# typed: true

require "dry-struct"
require_relative "../../app"
require_relative "../../types"

module App::Controllers::Schemas
  class FieldPayload < Dry::Struct
    transform_keys(&:to_sym)

    attribute :name, App::Types::String
    attribute :type, App::Types::String
  end
end
