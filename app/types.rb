# typed: ignore

require "dry-types"

module App::Types
  Types = Dry.Types(default: :strict)
  String = Types::String
  Integer = Types::Integer
  Float = Types::Float
  Bool = Types::Bool
  Array = Types::Array
end
