# typed: true

require "sorbet-runtime"
require_relative "../../app"
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

class App::Controllers::EntitiesController
  extend T::Sig

  Entities = App::Controllers::Entities
  Controllers = App::Controllers
  Services = App::Services
  Domain = App::Domain
  Response = Controllers::Shared::Response
  Request = Controllers::Shared::Request

  sig { params(service: Services::DynamicEntityService).void }
  def initialize(service: Services::DynamicEntityService.new)
    super()
    @service = T.let(service, Services::DynamicEntityService)
  end

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
  rescue StandardError => error
    Response.new(status: 500, body: Controllers::Shared::ErrorResponse.new(error: error.message))
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
  rescue ArgumentError => error
    Response.new(status: 422, body: Controllers::Shared::ErrorResponse.new(error: error.message))
  rescue StandardError => error
    Response.new(status: 500, body: Controllers::Shared::ErrorResponse.new(error: error.message))
  end
end
