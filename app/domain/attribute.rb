# typed: true

require "sorbet-runtime"
require_relative "../app"

module App::Domain
  class Attribute
    extend T::Sig

    sig { returns(Symbol) }
    attr_reader :name

    sig { returns(T.untyped) }
    attr_reader :value

    sig { params(name: T.any(String, Symbol), value: T.untyped).void }
    def initialize(name:, value:)
      @name = T.let(name.to_sym, Symbol)
      @value = value
    end
  end
end
