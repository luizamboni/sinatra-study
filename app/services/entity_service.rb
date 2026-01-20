# typed: true

require "sorbet-runtime"
require_relative "../app"
require_relative "../infrastructure/repository"
require_relative "../domain/entity"

module App::Services
  class EntityService
    extend T::Sig

    sig do
      params(
        entity_repo: T.any(
          App::Infrastructure::Repository[App::Domain::Entity],
          App::Infrastructure::SqliteRepository[App::Domain::Entity]
        )
      ).void
    end
    def initialize(entity_repo: App::Infrastructure::Repository.new(type: App::Domain::Entity))
      @entity_repo = T.let(
        entity_repo,
        T.any(
          App::Infrastructure::Repository[App::Domain::Entity],
          App::Infrastructure::SqliteRepository[App::Domain::Entity]
        )
      )
    end

    sig { params(entity: App::Domain::Entity).returns(App::Domain::Entity) }
    def add_entity(entity:)
      @entity_repo.add(item: entity)
    end

    sig { params(schema_name: T.any(String, Symbol)).returns(T::Array[App::Domain::Entity]) }
    def entities_for(schema_name:)
      name = schema_name.to_s
      @entity_repo.all.select { |entity| entity.schema_name == name }
    end

    sig { returns(T::Array[App::Domain::Entity]) }
    def all
      @entity_repo.all
    end
  end
end
