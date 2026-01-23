# typed: false

require "sinatra/base"
require "dry-struct"

require_relative "../app"
require_relative "../app/dependency_builder"
require_relative "../app/app"
require_relative "open_api"
require_relative "../errors/validation_error"
require_relative "../controllers/schemas/controller"
require_relative "../controllers/entities/controller"

module App::Api
  class AppApiRoutes < Sinatra::Base

   include App::Controllers

    V1 = App::App::App.new(self)
    V1.configure_defaults
    V1.define_error_fallback(ArgumentError, status: 422, response_class: Shared::ErrorResponse)
    V1.define_error_fallback(Dry::Struct::Error, status: 422, response_class: Shared::ErrorResponse)
    V1.define_error_fallback(App::Errors::ValidationError, status: 422, response_class: Shared::ErrorResponse)
    V1.define_error_fallback(StandardError, status: 500, response_class: Shared::ErrorResponse)

    V1.get "/schemas", nil, { 200 => Schemas::SchemasResponse } do |request|
      schemas_controller.index(request: request)
    end

    V1.post "/schemas",
            Schemas::CreateSchemaRequest,
            {
              201 => Schemas::SchemaPayload,
              [422, 500] => Shared::ErrorResponse
            } do |request, _payload|
      schemas_controller.create(request: request)
    end

    V1.get "/entities/:schema", nil, { 200 => Entities::EntitiesResponse } do |request|
      entities_controller.index(request: request)
    end

    V1.post "/entities/:schema", Entities::CreateEntityRequest, { 200 => Entities::EntityPayload, [422, 500] => Shared::ErrorResponse} do |request, _payload|
      entities_controller.create(request: request)
    end
    V1.define_swagger_routes


    V2 = App::App::App.new(
      self,
      version: "v2",
      docs_proc: ->(spec_url) { App::Api::OpenApi.ui_html(spec_url: spec_url) }
    )
    V2.configure_defaults
    V2.define_error_fallback(ArgumentError, status: 422, response_class: Shared::ErrorResponse)
    V2.define_error_fallback(Dry::Struct::Error, status: 422, response_class: Shared::ErrorResponse)
    V2.define_error_fallback(App::Errors::ValidationError, status: 422, response_class: Shared::ErrorResponse)
    V2.define_error_fallback(StandardError, status: 500, response_class: Shared::ErrorResponse)

    V2.get("/v2/schemas", nil, { 200 => Schemas::SchemasResponse }) do |request|
      schemas_controller.index(request: request)
    end

    V2.post("/v2/schemas", Schemas::CreateSchemaRequest, { 201 => Schemas::SchemaPayload, [422, 500] => Shared::ErrorResponse}) do |request, _payload|
      schemas_controller.create(request: request)
    end

    V2.get("/v2/entities/:schema", nil, { 200 => Entities::EntitiesResponse }) do |request|
      entities_controller.index(request: request)
    end

    V2.post("/v2/entities/:schema", Entities::CreateEntityRequest, { 200 => Entities::EntityPayload, [422, 500] => Shared::ErrorResponse}) do |request, _payload|
      entities_controller.create(request: request)
    end
    V2.define_swagger_routes

    # above define_swagger_routes to be not registered 
    get "/:schema/swagger.json" do
      request_obj = build_request_from_params
      response = schemas_controller.swagger_json(request: request_obj, prefix: nil)
      render_response(response)
    end

    get "/:schema/docs" do
      request_obj = build_request_from_params
      response = schemas_controller.swagger_docs(request: request_obj, prefix: nil)
      render_response(response)
    end

    get "/v2/:schema/swagger.json" do
      request_obj = build_request_from_params
      response = schemas_controller.swagger_json(request: request_obj, prefix: "/v2")
      render_response(response)
    end

    get "/v2/:schema/docs" do
      request_obj = build_request_from_params
      response = schemas_controller.swagger_docs(request: request_obj, prefix: "/v2")
      render_response(response)
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

    def build_request_from_params
      params_hash = params.to_h.transform_values(&:to_s)
      App::Controllers::Shared::Request.new(params: params_hash, json: nil)
    end

    def render_response(response)
      status response.status
      if response.content_type&.include?("html")
        content_type :html
        response.body.to_s
      else
        content_type :json
        JSON.generate(response.body)
      end
    end

  end
end
