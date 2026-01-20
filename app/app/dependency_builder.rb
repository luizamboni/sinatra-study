# typed: true

require "sorbet-runtime"
require_relative "../app"
require_relative "../infrastructure/repository"
require_relative "../infrastructure/sqlite_repository"
require_relative "../domain/schema"
require_relative "../domain/entity"
require_relative "../services/schema_service"
require_relative "../services/entity_service"
require_relative "../services/dynamic_entity_service"
require_relative "../controllers/schemas/controller"
require_relative "../controllers/entities/controller"

module App::App::DependencyBuilder
  extend T::Sig

  class Container
    extend T::Sig

    sig { params(db_path: String, repository_class: T.class_of(Object)).void }
    def initialize(db_path:, repository_class: App::Infrastructure::SqliteRepository)
      @db_path = T.let(db_path, String)
      @repository_class = T.let(repository_class, T.class_of(Object))
    end

    sig { returns(T.untyped) }
    def schema_repo
      @schema_repo ||= build_repo(App::Domain::Schema)
    end

    sig { returns(T.untyped) }
    def entity_repo
      @entity_repo ||= build_repo(App::Domain::Entity)
    end

    sig { returns(App::Services::SchemaService) }
    def schema_service
      @schema_service ||= App::Services::SchemaService.new(schema_repo: schema_repo)
    end

    sig { returns(App::Services::EntityService) }
    def entity_service
      @entity_service ||= App::Services::EntityService.new(entity_repo: entity_repo)
    end

    sig { returns(App::Services::DynamicEntityService) }
    def dynamic_entity_service
      @dynamic_entity_service ||= App::Services::DynamicEntityService.new(
        schema_service: schema_service,
        entity_service: entity_service
      )
    end

    sig { returns(App::Controllers::SchemasController) }
    def schemas_controller
      @schemas_controller ||= App::Controllers::SchemasController.new(service: dynamic_entity_service)
    end

    sig { returns(App::Controllers::EntitiesController) }
    def entities_controller
      @entities_controller ||= App::Controllers::EntitiesController.new(service: dynamic_entity_service)
    end

    private

    sig { params(type: T.class_of(Object)).returns(T.untyped) }
    def build_repo(type)
      if @repository_class == App::Infrastructure::Repository
        @repository_class.new(type: type)
      else
        @repository_class.new(type: type, db_path: @db_path)
      end
    end
  end

  sig { params(db_path: String, repository_class: T.class_of(Object)).returns(Container) }
  def self.build(db_path: "db/app.sqlite3", repository_class: App::Infrastructure::SqliteRepository)
    Container.new(db_path: db_path, repository_class: repository_class)
  end
end
