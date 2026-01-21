# typed: true

require "sorbet-runtime"
require_relative "../../app"
require_relative "../base_controller"
require_relative "attribute_payload"
require_relative "entity_payload"
require_relative "entity_item"
require_relative "entities_response"
require_relative "create_entity_request"
require_relative "../shared/response"
require_relative "../shared/error_response"
require_relative "../shared/request"
require_relative "../../domain/attribute"
require_relative "../../services/dynamic_entity_service"

class App::Controllers::EntitiesController < App::Controllers::Base
  extend T::Sig

  Entities = App::Controllers::Entities
  Controllers = App::Controllers
  Services = App::Services
  Domain = App::Domain
  ErrorResponse = Controllers::ErrorResponse
  Response = Controllers::Response
  Request = Controllers::Request

  sig { params(service: Services::DynamicEntityService).void }
  def initialize(service: Services::DynamicEntityService.new)
    super()
    @service = T.let(service, Services::DynamicEntityService)
  end

  SCHEMA_PATH_PARAM = T.let(
    {
      "name" => "schema",
      "in" => "path",
      "required" => true,
      "schema" => { "type" => "string" }
    }.freeze,
    T::Hash[String, T.untyped]
  )

  register_route(
    path: "/entities/{schema}",
    method: "get",
    summary: "List entities for schema",
    action: :index,
    parameters: [SCHEMA_PATH_PARAM],
    response_body: Entities::EntitiesResponse,
    responses: {
      "200" => {
        "description" => "Entities list"
      },
      "500" => {
        "description" => "Internal Server Error",
        "schema_ref" => ErrorResponse
      }
    }
  )

  register_route(
    path: "/entities/{schema}",
    method: "post",
    summary: "Create entity for schema",
    action: :create,
    parameters: [SCHEMA_PATH_PARAM],
    request_body: Entities::CreateEntityRequest,
    response_body: Entities::EntityPayload,
    responses: {
      "200" => {
        "description" => "Entity created"
      },
      "422" => {
        "description" => "Validation error",
        "schema_ref" => ErrorResponse
      },
      "500" => {
        "description" => "Internal Server Error",
        "schema_ref" => ErrorResponse
      }
    }
  )

  sig do
    params(
      request: Request[T.untyped]
    ).returns(Response[Entities::EntitiesResponse])
  end
  def index(request:)
    schema_name = request.params.fetch("schema")
    entities = @service.entities_for(schema_name: schema_name)
    payload = Entities::EntitiesResponse.new(
      schema: schema_name,
      entities: entities.map do |entity|
        Entities::EntityItem.new(
          attributes: entity.attributes.map do |attribute|
            Entities::AttributePayload.new(name: attribute.name.to_s, value: attribute.value)
          end
        )
      end
    )
    Response.new(status: 200, body: payload)
  end

  sig do
    params(
      request: Request[Entities::CreateEntityRequest]
    ).returns(Response[Entities::EntityPayload])
  end
  def create(request:)
    schema_name = request.params.fetch("schema")
    payload = T.must(request.json)
    attributes = payload.attributes.map do |attribute|
      Domain::Attribute.new(name: attribute.name, value: attribute.value)
    end
    
    entity = @service.create_entity(schema_name: schema_name, attributes: attributes)

    response_payload = Entities::EntityPayload.new(
      schema: entity.schema_name,
      attributes: entity.attributes.map do |attribute|
        Entities::AttributePayload.new(name: attribute.name.to_s, value: attribute.value)
      end
    )

    Response.new(status: 200, body: response_payload)
  end
end
