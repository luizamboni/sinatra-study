# typed: true

require "sorbet-runtime"
require_relative "../../app"
require_relative "field_payload"
require_relative "schema_payload"
require_relative "schemas_response"
require_relative "create_schema_request"
require_relative "../shared/response"
require_relative "../shared/error_response"
require_relative "../shared/request"
require_relative "../../domain/field"
require_relative "../../services/dynamic_entity_service"

class App::Controllers::SchemasController
  extend T::Sig

  Schemas = App::Controllers::Schemas
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
    ).returns(Response[Schemas::SchemasResponse])
  end
  def index(request:)
    payload = Schemas::SchemasResponse.new(
      schemas: @service.schemas.map do |schema|
        Schemas::SchemaPayload.new(
          name: schema.name,
          fields: schema.fields.map { |name, type| Schemas::FieldPayload.new(name: name.to_s, type: type.to_s) }
        )
      end
    )
    Response.new(status: 200, body: payload)
  rescue StandardError => error
    Response.new(status: 500, body: Controllers::Shared::ErrorResponse.new(error: error.message))
  end

  sig do
    params(
      request: Request[Schemas::CreateSchemaRequest]
    ).returns(Response[Schemas::SchemaPayload])
  end
  def create(request:)
    payload = T.must(request.json)
    fields = payload.fields.map do |field|
      Domain::Field.new(name: field.name, type: field.type)
    end
    schema = @service.define_schema(name: payload.name, fields: fields)
    response_payload = Schemas::SchemaPayload.new(
      name: schema.name,
      fields: schema.fields.map { |name, type| Schemas::FieldPayload.new(name: name.to_s, type: type.to_s) }
    )
    Response.new(status: 201, body: response_payload)
  end
end
