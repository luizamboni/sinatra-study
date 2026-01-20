# typed: true

require "sorbet-runtime"
require_relative "../app"
require_relative "attribute"

module App::Domain
  class Entity
    extend T::Sig

    sig { returns(String) }
    attr_reader :schema_name

    sig { returns(T::Array[Attribute]) }
    attr_reader :attributes

    # Entities are thin data holders validated elsewhere.
    sig { params(schema_name: T.any(String, Symbol), attributes: T::Array[Attribute]).void }
    def initialize(schema_name:, attributes:)
      @schema_name = T.let(schema_name.to_s, String)
      @attributes = T.let(attributes, T::Array[Attribute])
    end
  end
end
