# typed: false

require "sinatra/base"

require_relative "../app"
require_relative "../app/dependency_builder"
require_relative "../app/app"
require_relative "helpers"
require_relative "sinatra_setup"
require_relative "../controllers/schemas/controller"
require_relative "../controllers/entities/controller"

module App::Api
  class AppApiRoutes < Sinatra::Base
    configure do
      SinatraSetup.configure(self)
    end

    helpers Helpers

    error ArgumentError do
      json_response({ error: env["sinatra.error"].message }, 422)
    end

    error do
      json_response({ error: "Internal Server Error" }, 500)
    end


    get "/schemas" do
      response = schemas_controller.index(request: build_request)
      json_response(normalize_payload(response.body), response.status)
    end

    post "/schemas" do
      request = build_request(coerce_class: App::Controllers::Schemas::CreateSchemaRequest)
      response = schemas_controller.create(request: request)
      json_response(normalize_payload(response.body), response.status)
    end

    get "/entities/:schema" do
      request = build_request
      response = entities_controller.index(request: request)
      json_response(normalize_payload(response.body), response.status)
    end

    post "/entities/:schema" do
      request = build_request(coerce_class: App::Controllers::Entities::CreateEntityRequest)
      response = entities_controller.create(request: request)
      json_response(normalize_payload(response.body), response.status)
    end


    get "/swagger.json" do
      json_response(App::Api::OpenApi.spec)
    end

    get "/swagger/:schema.json" do
      schema_name = params.fetch("schema").to_s
      schema = dynamic_entity_service.find_schema(name: schema_name)
      unless schema
        return json_response({ error: "Schema not found: #{schema_name}" }, 404)
      end

      json_response(App::Api::OpenApi.spec_for_schema(schema: schema))
    end

    get "/docs" do
      content_type :html
      App::Api::OpenApi.ui_html
    end

    get "/docs/:schema" do

      schema_name = params.fetch("schema").to_s
      schema = dynamic_entity_service.find_schema(name: schema_name)
      unless schema
        return json_response({ error: "Schema not found: #{schema_name}" }, 404)
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

    get V2.swagger_path do
      spec = V2.swagger_spec
      unless spec
        return json_response({ error: "Swagger spec not configured" }, 500)
      end
      json_response(spec)
    end

    get V2.docs_path do
      html = V2.docs_html
      unless html
        return json_response({ error: "Swagger UI not configured" }, 500)
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
