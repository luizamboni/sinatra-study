# typed: true

require "sorbet-runtime"
require_relative "../app"
require_relative "../errors/validation_error"
require_relative "../infrastructure/repository"
require_relative "../domain/schema"
require_relative "../domain/field"

module App::Services
  class SchemaService
    extend T::Sig

    sig do
      params(
        schema_repo: T.any(
          App::Infrastructure::Repository[App::Domain::Schema],
          App::Infrastructure::SqliteRepository[App::Domain::Schema]
        )
      ).void
    end
    def initialize(schema_repo: App::Infrastructure::Repository.new(type: App::Domain::Schema))
      @schema_repo = T.let(
        schema_repo,
        T.any(
          App::Infrastructure::Repository[App::Domain::Schema],
          App::Infrastructure::SqliteRepository[App::Domain::Schema]
        )
      )
    end

    sig { params(name: T.any(String, Symbol), fields: T::Array[App::Domain::Field]).returns(App::Domain::Schema) }
    def define_schema(name:, fields:)
      if find_schema(name: name)
        raise App::Errors::ValidationError.new(
          "Invalid request payload",
          details: ["Schema already defined: #{name}"]
        )
      end

      schema = App::Domain::Schema.new(name: name, fields: fields)
      @schema_repo.add(item: schema)
    end

    sig { params(name: T.any(String, Symbol)).returns(T.nilable(App::Domain::Schema)) }
    def find_schema(name:)
      target = name.to_s
      @schema_repo.find_by { |schema| schema.name == target }
    end

    sig { returns(T::Array[App::Domain::Schema]) }
    def all
      @schema_repo.all
    end
  end
end
