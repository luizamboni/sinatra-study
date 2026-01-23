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

  sig do
    params(
      request: Request[T.untyped],
      prefix: T.nilable(String)
    ).returns(Response[T.untyped])
  end
  def swagger_docs(request:, prefix: nil)
    schema_name = request.params.fetch("schema")
    spec = swagger_spec_for(schema_name: schema_name, prefix: prefix)
    unless spec
      error_payload = Controllers::Shared::ErrorResponse.new(error: "Schema not found: #{schema_name}")
      return Response.new(status: 404, body: error_payload)
    end

    spec_path = prefix ? "#{prefix}/#{schema_name}/swagger.json" : "/#{schema_name}/swagger.json"
    html = App::Api::OpenApi.ui_html(spec_url: spec_path)
    Response.new(status: 200, body: html, content_type: "text/html")
  end

  sig do
    params(
      request: Request[T.untyped],
      prefix: T.nilable(String)
    ).returns(Response[T.untyped])
  end
  def swagger_json(request:, prefix: nil)
    schema_name = request.params.fetch("schema")
    spec = swagger_spec_for(schema_name: schema_name, prefix: prefix)
    unless spec
      error_payload = Controllers::Shared::ErrorResponse.new(error: "Schema not found: #{schema_name}")
      return Response.new(status: 404, body: error_payload)
    end

    Response.new(status: 200, body: spec, content_type: "application/json")
  end

  sig do
    params(
      schema_name: String,
      prefix: T.nilable(String)
    ).returns(T.nilable(T::Hash[String, T.untyped]))
  end
  def swagger_spec_for(schema_name:, prefix: nil)
    schema = @service.find_schema(name: schema_name)
    return nil unless schema

    component_base = schema_component_name(schema.name)
    attribute_item_name = "#{component_base}Attribute"
    entity_name = "#{component_base}Entity"
    entities_response_name = "#{component_base}EntitiesResponse"

    attribute_one_of = schema.fields.map do |field_name, field_type|
      {
        "type" => "object",
        "properties" => {
          "name" => {
            "type" => "string",
            "enum" => [field_name.to_s]
          },
          "value" => schema_for_field_type(field_type)
        },
        "required" => ["name", "value"]
      }
    end

    components = {
      "schemas" => {
        attribute_item_name => {
          "oneOf" => attribute_one_of
        },
        entity_name => {
          "type" => "object",
          "properties" => {
            "schema" => { "type" => "string" },
            "attributes" => {
              "type" => "array",
              "items" => { "$ref" => "#/components/schemas/#{attribute_item_name}" }
            }
          },
          "required" => ["schema", "attributes"]
        },
        entities_response_name => {
          "type" => "object",
          "properties" => {
            "schema" => { "type" => "string" },
            "entities" => {
              "type" => "array",
              "items" => {
                "type" => "object",
                "properties" => {
                  "attributes" => {
                    "type" => "array",
                    "items" => { "$ref" => "#/components/schemas/#{attribute_item_name}" }
                  }
                },
                "required" => ["attributes"]
              }
            }
          },
          "required" => ["schema", "entities"]
        }
      }
    }

    base_path = prefix ? "#{prefix}/entities/#{schema.name}" : "/entities/#{schema.name}"
    {
      "openapi" => "3.0.0",
      "info" => {
        "title" => "#{schema.name} API",
        "version" => "1.0.0"
      },
      "paths" => {
        base_path => {
          "get" => {
            "summary" => "GET #{base_path}",
            "responses" => {
              "200" => {
                "description" => "Success",
                "content" => {
                  "application/json" => {
                    "schema" => { "$ref" => "#/components/schemas/#{entities_response_name}" }
                  }
                }
              }
            }
          },
          "post" => {
            "summary" => "POST #{base_path}",
            "requestBody" => {
              "required" => true,
              "content" => {
                "application/json" => {
                  "schema" => { "$ref" => "#/components/schemas/#{entity_name}" }
                }
              }
            },
            "responses" => {
              "200" => {
                "description" => "Success",
                "content" => {
                  "application/json" => {
                    "schema" => { "$ref" => "#/components/schemas/#{entity_name}" }
                  }
                }
              }
            }
          }
        }
      },
      "components" => components
    }
  end

  private

  def schema_component_name(name)
    parts = name.to_s.split(/[^a-zA-Z0-9]+/).reject(&:empty?)
    base = parts.map { |part| part[0].upcase + part[1..].to_s }.join
    base.empty? ? "Schema" : base
  end

  def schema_for_field_type(field_type)
    case field_type
    when :string
      { "type" => "string" }
    when :integer
      { "type" => "integer" }
    when :float
      { "type" => "number", "format" => "float" }
    when :numeric
      { "type" => "number" }
    when :boolean
      { "type" => "boolean" }
    else
      { "type" => "string" }
    end
  end
end
