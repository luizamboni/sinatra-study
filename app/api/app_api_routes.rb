# typed: false

require "sinatra/base"
require "debug"

require_relative "../app"
require_relative "../app/dependency_builder"
require_relative "helpers"
require_relative "sinatra_setup"
require_relative "../controllers/schemas/controller"
require_relative "../controllers/entities/controller"

module App::Api
  class AppApiRoutes < Sinatra::Base
    configure do
      SinatraSetup.configure(self)
      SinatraSetup.register_open_api_routes(self, settings.dynamic_entity_service)
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


    private

    def container
      settings.container
    end

    def schemas_controller
      @schemas_controller ||= container.schemas_controller
    end

    def entities_controller
      @entities_controller ||= container.entities_controller
    end
  end
end
