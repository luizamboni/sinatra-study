# typed: true

require "sorbet-runtime"
require_relative "../app"
require_relative "field"

module App::Domain
  class Schema
    extend T::Sig

    # Field types are symbolic to keep the schema runtime-agnostic.
    FieldType = T.type_alias { Symbol }

    sig { returns(String) }
    attr_reader :name

    sig { returns(T::Hash[Symbol, FieldType]) }
    attr_reader :fields

    sig { params(name: T.any(String, Symbol), fields: T::Array[Field]).void }
    def initialize(name:, fields:)
      @name = T.let(name.to_s, String)
      @fields = T.let(normalize_fields(fields: fields), T::Hash[Symbol, FieldType])
    end

    private

    sig { params(fields: T::Array[Field]).returns(T::Hash[Symbol, FieldType]) }
    def normalize_fields(fields:)

      fields.each_with_object({}) do |field, acc|
        acc[field.name] = field.type
      end
    end
  end
end
