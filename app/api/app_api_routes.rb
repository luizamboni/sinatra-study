# typed: false

require "sinatra/base"

require_relative "../app"
require_relative "../app/dependency_builder"
require_relative "../app/app"
require_relative "open_api"
require_relative "../controllers/schemas/controller"
require_relative "../controllers/entities/controller"

module App::Api
  class AppApiRoutes < Sinatra::Base

    error ArgumentError do
      content_type :json
      status 422
      JSON.generate({ error: env["sinatra.error"].message })
    end

    error do
      content_type :json
      status 500
      JSON.generate({ error: "Internal Server Error" })
    end


    V1 = App::App::App.new(self)
    V1.configure_defaults

    V1.get "/schemas", nil, [App::Controllers::Schemas::SchemasResponse] do |request|
      schemas_controller.index(request: request)
    end

    V1.post "/schemas", App::Controllers::Schemas::CreateSchemaRequest, [App::Controllers::Schemas::SchemaPayload] do |request, _payload|
      schemas_controller.create(request: request)
    end

    V1.get "/entities/:schema", nil, [App::Controllers::Entities::EntitiesResponse] do |request|
      entities_controller.index(request: request)
    end

    V1.post "/entities/:schema", App::Controllers::Entities::CreateEntityRequest, [App::Controllers::Entities::EntityPayload] do |request, _payload|
      entities_controller.create(request: request)
    end


    get "/swagger.json" do
      content_type :json
      JSON.generate(App::Api::OpenApi.spec)
    end

    get "/swagger/:schema.json" do
      schema_name = params.fetch("schema").to_s
      schema = dynamic_entity_service.find_schema(name: schema_name)
      unless schema
        content_type :json
        status 404
        return JSON.generate({ error: "Schema not found: #{schema_name}" })
      end

      content_type :json
      JSON.generate(App::Api::OpenApi.spec_for_schema(schema: schema))
    end

    get "/docs" do
      content_type :html
      App::Api::OpenApi.ui_html
    end

    get "/docs/:schema" do

      schema_name = params.fetch("schema").to_s
      schema = dynamic_entity_service.find_schema(name: schema_name)
      unless schema
        content_type :json
        status 404
        return JSON.generate({ error: "Schema not found: #{schema_name}" })
      end

      content_type :html
      App::Api::OpenApi.ui_html(spec_url: "/swagger/#{schema_name}.json")
    end

    V2 = App::App::App.new(
      self,
      version: "v2",
      openapi_proc: -> { App::Api::OpenApi.spec },
      docs_proc: ->(spec_url) { App::Api::OpenApi.ui_html(spec_url: spec_url) }
    )
    V2.configure_defaults

    get V2.swagger_path do
      spec = V2.swagger_spec
      unless spec
        content_type :json
        status 500
        return JSON.generate({ error: "Swagger spec not configured" })
      end
      content_type :json
      JSON.generate(spec)
    end

    get V2.docs_path do
      html = V2.docs_html
      unless html
        content_type :json
        status 500
        return JSON.generate({ error: "Swagger UI not configured" })
      end
      content_type :html
      html
    end

    V2.get "/v2/schemas", nil, [App::Controllers::Schemas::SchemasResponse] do |request|
      schemas_controller.index(request: request)
    end

    V2.post "/v2/schemas", App::Controllers::Schemas::CreateSchemaRequest, [App::Controllers::Schemas::SchemaPayload] do |request, _payload|
      schemas_controller.create(request: request)
    end

    V2.get "/v2/entities/:schema", nil, [App::Controllers::Entities::EntitiesResponse] do |request|
      entities_controller.index(request: request)
    end

    V2.post "/v2/entities/:schema", App::Controllers::Entities::CreateEntityRequest, [App::Controllers::Entities::EntityPayload] do |request, _payload|
      entities_controller.create(request: request)
    end


    private

    def dynamic_entity_service
      @dynamic_entity_service ||= container.dynamic_entity_service
    end

    def container
      @container ||= App::App::DependencyBuilder.build()
    end

    def schemas_controller
      @schemas_controller ||= container.schemas_controller
    end

    def entities_controller
      @entities_controller ||= container.entities_controller
    end
  end
end
