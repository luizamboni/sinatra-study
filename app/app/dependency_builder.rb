# typed: true

require "sorbet-runtime"
require_relative "../app"
require_relative "../infrastructure/repository"
require_relative "../infrastructure/sqlite_repository"
require_relative "../infrastructure/spanner_repository"
require_relative "../domain/schema"
require_relative "../domain/entity"
require_relative "../services/schema_service"
require_relative "../services/entity_service"
require_relative "../services/dynamic_entity_service"
require_relative "../controllers/schemas/controller"
require_relative "../controllers/entities/controller"

module App::App::DependencyBuilder
  extend T::Sig

  RepoClass = T.type_alias do
    T.any(
      T.class_of(App::Infrastructure::Repository),
      T.class_of(App::Infrastructure::SqliteRepository),
      T.class_of(App::Infrastructure::SpannerRepository)
    )
  end

  SpannerConfig = T.type_alias do
    {
      project_id: String,
      instance_id: String,
      database_id: String
    }
  end

  class Container
    extend T::Sig
    @instance = T.let(nil, T.nilable(Container))

    class << self
      extend T::Sig

      sig { params(db_path: String, spanner_config: SpannerConfig, repository_class: RepoClass).returns(Container) }
      def instance(db_path:, spanner_config:, repository_class:)
        @instance ||= new(
          db_path: db_path,
          spanner_config: spanner_config,
          repository_class: repository_class
        )
      end
    end

    private_class_method :new

    sig { params(db_path: String, spanner_config: SpannerConfig, repository_class: RepoClass).void }
    def initialize(db_path:, spanner_config:, repository_class: App::Infrastructure::SqliteRepository)
      @db_path = T.let(db_path, String)
      @spanner_config = T.let(spanner_config, SpannerConfig)
      @repository_class = T.let(repository_class, RepoClass)
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
        repo_class = T.cast(@repository_class, T.class_of(App::Infrastructure::Repository))
        repo_class.new(type: type)
      elsif @repository_class == App::Infrastructure::SpannerRepository
        repo_class = T.cast(@repository_class, T.class_of(App::Infrastructure::SpannerRepository))
        repo_class.new(
          type: type,
          project_id: @spanner_config[:project_id],
          instance_id: @spanner_config[:instance_id],
          database_id: @spanner_config[:database_id]
        )
      else
        repo_class = T.cast(@repository_class, T.class_of(App::Infrastructure::SqliteRepository))
        repo_class.new(type: type, db_path: @db_path)
      end
    end
  end

  sig { params(repository_class: T.nilable(RepoClass)).returns(Container) }
  def self.build(repository_class: nil)
    repo_class = repository_class || default_repository_class
    db_path = if ENV["RACK_ENV"] == "test"
      ":memory:"
    else
      "db/app.sqlite3"
    end

    spanner_config = {
      project_id: ENV.fetch("SPANNER_PROJECT_ID", "local-project"),
      instance_id: ENV.fetch("SPANNER_INSTANCE_ID", "local-instance"),
      database_id: ENV.fetch("SPANNER_DATABASE_ID", "local-db")
    }

    Container.instance(
      db_path: db_path,
      repository_class: repo_class,
      spanner_config: spanner_config
    )
  end

  sig { returns(RepoClass) }
  def self.default_repository_class
    return App::Infrastructure::Repository if ENV["APP_REPOSITORY"] == "memory"
    return App::Infrastructure::SpannerRepository if ENV["APP_REPOSITORY"] == "spanner"
    return App::Infrastructure::SpannerRepository if ENV["SPANNER_EMULATOR_HOST"]

    App::Infrastructure::SqliteRepository
  end
end
