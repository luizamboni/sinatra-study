# typed: true

require "sorbet-runtime"
require_relative "../app"

module App::Domain
  class Field
    extend T::Sig

    ALLOWED_TYPES = T.let(
      [
        :string,
        :integer,
        :float,
        :numeric,
        :boolean
      ].freeze,
      T::Array[Symbol]
    )

    sig { returns(Symbol) }
    attr_reader :name

    sig { returns(Symbol) }
    attr_reader :type

    sig do
      params(
        name: T.any(String, Symbol),
        type: T.any(Symbol, String)
      ).void
    end
    def initialize(name:, type:)
      if name.to_s.strip.empty?
        raise ArgumentError, "Field name must be present"
      end

      @name = T.let(name.to_sym, Symbol)
      normalized = normalize_type(type: type)
      @type = T.let(normalized, Symbol)
    end

    private

    sig { params(type: T.any(Symbol, String)).returns(Symbol) }
    def normalize_type(type:)
      unless type.is_a?(Symbol) || type.is_a?(String)
        raise ArgumentError, "Field type must be a Symbol or String"
      end

      normalized = type.to_sym
      unless ALLOWED_TYPES.include?(normalized)
        raise ArgumentError, "Field type not allowed: #{normalized}"
      end

      normalized
    end
  end
end
