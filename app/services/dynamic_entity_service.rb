# typed: true

require "sorbet-runtime"
require_relative "../app"
require_relative "schema_service"
require_relative "entity_service"
require_relative "../domain/attribute"

module App::Services
  class DynamicEntityService
    extend T::Sig

    sig { params(schema_service: SchemaService, entity_service: EntityService).void }
    # Compose services to keep schema and entity logic separate.
    def initialize(
      schema_service: SchemaService.new,
      entity_service: EntityService.new
    )
      @schema_service = T.let(schema_service, SchemaService)
      @entity_service = T.let(entity_service, EntityService)
    end

    # Define the schema once before creating entities.
    sig { params(name: T.any(String, Symbol), fields: T::Array[App::Domain::Field]).returns(App::Domain::Schema) }
    def define_schema(name:, fields:)
      @schema_service.define_schema(name: name, fields: fields)
    end

    sig { params(name: T.any(String, Symbol)).returns(T.nilable(App::Domain::Schema)) }
    def find_schema(name:)
      @schema_service.find_schema(name: name)
    end

    # Validate attributes against the schema before storing.
    sig { params(schema_name: T.any(String, Symbol), attributes: T::Array[App::Domain::Attribute]).returns(App::Domain::Entity) }
    def create_entity(schema_name:, attributes:)
      schema = @schema_service.find_schema(name: schema_name)
      raise ArgumentError, "Schema not found: #{schema_name}" unless schema

      normalized_attributes = normalize_attributes(attributes: attributes)
      attributes_by_name = attributes_map(attributes: normalized_attributes)
      validate_attributes!(schema: schema, attributes: attributes_by_name)

      entity = App::Domain::Entity.new(schema_name: schema.name, attributes: normalized_attributes)
      @entity_service.add_entity(entity: entity)
    end

    sig { returns(T::Array[App::Domain::Schema]) }
    def schemas
      @schema_service.all
    end

    sig { params(schema_name: T.any(String, Symbol)).returns(T::Array[App::Domain::Entity]) }
    def entities_for(schema_name:)
      @entity_service.entities_for(schema_name: schema_name)
    end

    private

    sig { params(attributes: T::Array[App::Domain::Attribute]).returns(T::Array[App::Domain::Attribute]) }
    def normalize_attributes(attributes:)
      unless attributes.is_a?(Array) && !attributes.empty?
        raise ArgumentError, "Attributes must be a non-empty Array"
      end

      attributes.each_with_object([]) do |attribute, acc|
        unless attribute.is_a?(App::Domain::Attribute)
          raise ArgumentError, "Each attribute must be an App::Domain::Attribute"
        end

        acc << attribute
      end
    end

    sig { params(attributes: T::Array[App::Domain::Attribute]).returns(T::Hash[Symbol, T.untyped]) }
    def attributes_map(attributes:)
      attributes.each_with_object({}) do |attribute, acc|
        acc[attribute.name] = attribute.value
      end
    end

    sig { params(schema: App::Domain::Schema, attributes: T::Hash[Symbol, T.untyped]).void }
    def validate_attributes!(schema:, attributes:)
      schema.fields.each do |field, expected|
        unless attributes.key?(field)
          raise ArgumentError, "Missing required field: #{field}"
        end

        value = attributes[field]
        unless matches_type?(expected: expected, value: value)
          raise ArgumentError, "Field #{field} expected #{expected.inspect}, got #{value.class}"
        end
      end

      extra = attributes.keys - schema.fields.keys
      return if extra.empty?

      raise ArgumentError, "Unknown fields: #{extra.join(', ')}"
    end

    sig { params(expected: App::Domain::Schema::FieldType, value: T.untyped).returns(T::Boolean) }
    def matches_type?(expected:, value:)
      case expected
      when :string
        value.is_a?(String)
      when :integer
        value.is_a?(Integer)
      when :float
        value.is_a?(Float)
      when :numeric
        value.is_a?(Numeric)
      when :boolean
        value == true || value == false
      else
        false
      end
    end
  end
end
