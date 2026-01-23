# typed: true

module App
  module Controllers
    module Entities
      class AttributePayload < ::Dry::Struct
        sig { returns(String) }
        def name; end

        sig { returns(T.untyped) }
        def value; end
      end

      class CreateEntityRequest < ::Dry::Struct
        sig { returns(T::Array[AttributePayload]) }
        def attributes; end

        sig { params(payload: T::Hash[T.untyped, T.untyped]).returns(CreateEntityRequest) }
        def self.from_hash(payload); end
      end
    end

    module Schemas
      class FieldPayload < ::Dry::Struct
        sig { returns(String) }
        def name; end

        sig { returns(String) }
        def type; end
      end

      class CreateSchemaRequest < ::Dry::Struct
        sig { returns(String) }
        def name; end

        sig { returns(T::Array[FieldPayload]) }
        def fields; end

        sig { params(payload: T::Hash[T.untyped, T.untyped]).returns(CreateSchemaRequest) }
        def self.from_hash(payload); end
      end
    end
  end
end
