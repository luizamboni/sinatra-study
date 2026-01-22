# typed: true

require "sorbet-runtime"
require_relative "../app"

module App::Infrastructure
  class Repository
    extend T::Generic
    extend T::Sig

    # Generic type parameter for the repository's element type.
    Elem = type_member

    sig { params(type: T::Class[Object]).void }
    def initialize(type:)
      # Keep the expected class for runtime checks and typed storage.
      @type = T.let(type, T::Class[Object])
      @items = T.let([], T::Array[Elem])
    end

    sig { params(item: Elem).returns(Elem) }
    def add(item:)
      validate_type!(item:)
      @items << item
      item
    end

    sig { returns(T::Array[Elem]) }
    def all
      @items.dup
    end

    sig { params(block: T.proc.params(item: Elem).returns(T::Boolean)).returns(T.nilable(Elem)) }
    def find_by(&block)
      @items.find(&block)
    end

    sig { returns(T::Array[Elem]) }
    def clear
      @items.clear
    end

    private

    sig { params(item: Elem).void }
    def validate_type!(item:)
      return if T.unsafe(item).is_a?(@type)

      raise ArgumentError, "Expected #{@type}, got #{T.unsafe(item).class}"
    end
  end
end
