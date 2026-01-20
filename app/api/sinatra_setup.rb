# typed: true

require "sinatra/base"
require "sorbet-runtime"
require_relative "../app"
require_relative "../infrastructure/repository"
require_relative "../infrastructure/sqlite_repository"
require_relative "../domain/schema"
require_relative "../domain/entity"
require_relative "../services/schema_service"
require_relative "../services/entity_service"
require_relative "../services/dynamic_entity_service"
require_relative "../app/dependency_builder"
require_relative "open_api"

module App::Api::SinatraSetup
  extend T::Sig

  sig { params(app: T.class_of(Sinatra::Base)).void }
  def self.configure(app)
    app.set :show_exceptions, false
    app.set :protection, false
    app.set :allow_hosts, ["localhost", "127.0.0.1", "[::1]"]

    db_path = if ENV["RACK_ENV"] == "test"
      ":memory:"
    else
      "db/app.sqlite3"
    end
    app.set :db_path, db_path

    container = App::App::DependencyBuilder.build(db_path: db_path)
    app.set :container, container
    app.set :dynamic_entity_service, container.dynamic_entity_service
  end

  sig { params(app: T.class_of(Sinatra::Base), entity_service: App::Services::DynamicEntityService).void }
  def self.register_open_api_routes(app, entity_service)
    app.get "/swagger.json" do
      json_response(App::Api::OpenApi.spec)
    end

    app.get "/swagger/:schema.json" do
      schema_name = params.fetch("schema").to_s
      schema = entity_service.find_schema(name: schema_name)
      unless schema
        return json_response({ error: "Schema not found: #{schema_name}" }, 404)
      end

      json_response(App::Api::OpenApi.spec_for_schema(schema: schema))
    end

    app.get "/docs" do
      content_type :html
      App::Api::OpenApi.ui_html
    end

    app.get "/docs/:schema" do
      schema_name = params.fetch("schema").to_s
      schema = entity_service.find_schema(name: schema_name)
      unless schema
        return json_response({ error: "Schema not found: #{schema_name}" }, 404)
      end

      content_type :html
      App::Api::OpenApi.ui_html(spec_url: "/swagger/#{schema_name}.json")
    end
  end
end
