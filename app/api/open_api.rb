# typed: true

require "sorbet-runtime"
require_relative "../app"
require_relative "../domain/schema"
require_relative "../controllers/base_controller"
require_relative "../controllers/schemas/controller"
require_relative "../controllers/entities/controller"
require_relative "../controllers/shared/error_response"

module App::Api
  class OpenApi
    extend T::Sig

    SCHEMAS_CONTROLLER = App::Controllers::SchemasController.new
    ENTITIES_CONTROLLER = App::Controllers::EntitiesController.new

    sig { returns(T::Hash[String, T.untyped]) }
    def self.spec
      paths = T.let({}, T::Hash[String, T::Hash[String, T.untyped]])
      schemas = T.let({}, T::Hash[String, T::Hash[String, T.untyped]])

      controllers.each do |controller_class, controller_instance|
        controller_class.open_api_routes.each do |path, methods|
          paths[path] ||= {}
          methods.each do |verb, metadata|
            action = metadata["x-action"]
            route_spec = build_route_spec(
              controller: controller_instance,
              action: action,
              metadata: metadata,
              schemas: schemas
            )
            paths[path][verb] = route_spec
          end
        end
      end

      {
        "openapi" => "3.0.3",
        "info" => {
          "title" => "Dynamic Entity API",
          "version" => "1.0.0"
        },
        "paths" => paths,
        "components" => {
          "schemas" => schemas
        }
      }
    end

    sig { params(schema: App::Domain::Schema).returns(T::Hash[String, T.untyped]) }
    def self.spec_for_schema(schema:)
      attribute_variants = schema.fields.map do |name, type|
        {
          "type" => "object",
          "required" => ["name", "value"],
          "properties" => {
            "name" => { "type" => "string", "enum" => [name.to_s] },
            "value" => openapi_value_schema(type: type)
          }
        }
      end

      {
        "openapi" => "3.0.3",
        "info" => {
          "title" => "Dynamic Entity API - #{schema.name}",
          "version" => "1.0.0"
        },
        "paths" => {
          "/entities/#{schema.name}" => {
            "get" => {
              "summary" => "List entities for #{schema.name}",
              "responses" => {
                "200" => {
                  "description" => "Entities list",
                  "content" => {
                    "application/json" => {
                      "schema" => { "$ref" => "#/components/schemas/EntitiesResponse" }
                    }
                  }
                },
                "500" => {
                  "description" => "Internal Server Error",
                  "content" => {
                    "application/json" => {
                      "schema" => { "$ref" => "#/components/schemas/ErrorResponse" }
                    }
                  }
                }
              }
            },
            "post" => {
              "summary" => "Create entity for #{schema.name}",
              "requestBody" => {
                "required" => true,
                "content" => {
                  "application/json" => {
                    "schema" => { "$ref" => "#/components/schemas/CreateEntityRequest" }
                  }
                }
              },
              "responses" => {
                "200" => {
                  "description" => "Entity created",
                  "content" => {
                    "application/json" => {
                      "schema" => { "$ref" => "#/components/schemas/Entity" }
                    }
                  }
                },
                "422" => {
                  "description" => "Validation error",
                  "content" => {
                    "application/json" => {
                      "schema" => { "$ref" => "#/components/schemas/ErrorResponse" }
                    }
                  }
                },
                "500" => {
                  "description" => "Internal Server Error",
                  "content" => {
                    "application/json" => {
                      "schema" => { "$ref" => "#/components/schemas/ErrorResponse" }
                    }
                  }
                }
              }
            }
          }
        },
        "components" => {
          "schemas" => {
            "ErrorResponse" => {
              "type" => "object",
              "required" => ["error"],
              "properties" => {
                "error" => { "type" => "string" }
              }
            },
            "Attribute" => {
              "oneOf" => attribute_variants
            },
            "Entity" => {
              "type" => "object",
              "required" => ["schema", "attributes"],
              "properties" => {
                "schema" => { "type" => "string", "enum" => [schema.name] },
                "attributes" => {
                  "type" => "array",
                  "items" => { "$ref" => "#/components/schemas/Attribute" }
                }
              }
            },
            "EntitiesResponse" => {
              "type" => "object",
              "required" => ["schema", "entities"],
              "properties" => {
                "schema" => { "type" => "string", "enum" => [schema.name] },
                "entities" => {
                  "type" => "array",
                  "items" => {
                    "type" => "object",
                    "required" => ["attributes"],
                    "properties" => {
                      "attributes" => {
                        "type" => "array",
                        "items" => { "$ref" => "#/components/schemas/Attribute" }
                      }
                    }
                  }
                }
              }
            },
            "CreateEntityRequest" => {
              "type" => "object",
              "required" => ["attributes"],
              "properties" => {
                "attributes" => {
                  "type" => "array",
                  "items" => { "$ref" => "#/components/schemas/Attribute" }
                }
              }
            }
          }
        }
      }
    end

    sig { params(spec_url: String).returns(String) }
    def self.ui_html(spec_url: "/swagger.json")
      <<~HTML
        <!doctype html>
        <html lang="en">
          <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <title>Swagger UI</title>
            <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
          </head>
          <body>
            <div id="swagger-ui"></div>
            <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
            <script>
              window.onload = function() {
                SwaggerUIBundle({
                  url: "#{spec_url}",
                  dom_id: "#swagger-ui",
                  defaultModelsExpandDepth: 2,
                  defaultModelRendering: "model",
                  docExpansion: "list"
                });
              };
            </script>
          </body>
        </html>
      HTML
    end

    sig { params(type: App::Domain::Schema::FieldType).returns(T::Hash[String, T.untyped]) }
    def self.openapi_value_schema(type:)
      case type
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

    private_class_method :openapi_value_schema

    sig { returns(T::Array[T.untyped]) }
    def self.controllers
      [
        [App::Controllers::SchemasController, SCHEMAS_CONTROLLER],
        [App::Controllers::EntitiesController, ENTITIES_CONTROLLER]
      ]
    end

    sig do
      params(
        controller: T.untyped,
        action: String,
        metadata: T::Hash[String, T.untyped],
        schemas: T::Hash[String, T::Hash[String, T.untyped]]
      ).returns(T::Hash[String, T.untyped])
    end
    def self.build_route_spec(controller:, action:, metadata:, schemas:)
      signature = T::Utils.signature_for_method(controller.method(action.to_sym))
      request_schema = request_body_schema(signature: signature, schemas: schemas)
      response_schema = response_body_schema(signature: signature, schemas: schemas)
      if response_schema && response_schema["$ref"] == "#/components/schemas/Response" && metadata["response_body"]
        response_schema = nil
      end
      response_schema ||= schema_ref_for(metadata["response_body"], schemas) if metadata["response_body"]

      route_spec = {
        "summary" => metadata.fetch("summary"),
        "responses" => build_responses(metadata: metadata, response_schema: response_schema, schemas: schemas)
      }
      route_spec["parameters"] = metadata["parameters"] if metadata["parameters"]
      request_schema ||= schema_ref_for(metadata["request_body"], schemas) if metadata["request_body"]
      if request_schema
        route_spec["requestBody"] = {
          "required" => true,
          "content" => {
            "application/json" => {
              "schema" => request_schema
            }
          }
        }
      end
      route_spec
    end

    sig do
      params(
        metadata: T::Hash[String, T.untyped],
        response_schema: T.nilable(T::Hash[String, T.untyped]),
        schemas: T::Hash[String, T::Hash[String, T.untyped]]
      ).returns(T::Hash[String, T.untyped])
    end
    def self.build_responses(metadata:, response_schema:, schemas:)
      responses = {}
      metadata.fetch("responses").each do |status, info|
        entry = { "description" => info.fetch("description") }
        schema_ref = info["schema_ref"]
        schema = if schema_ref
          schema_ref_for(schema_ref, schemas)
        else
          response_schema
        end
        if schema
          entry["content"] = {
            "application/json" => {
              "schema" => schema
            }
          }
        end
        responses[status] = entry
      end
      responses
    end

    sig do
      params(
        signature: T::Private::Methods::Signature,
        schemas: T::Hash[String, T::Hash[String, T.untyped]]
      ).returns(T.nilable(T::Hash[String, T.untyped]))
    end
    def self.request_body_schema(signature:, schemas:)
      request_type = signature.kwarg_types[:request]
      return nil unless request_type

      payload_type = extract_request_payload_type(request_type)
      return nil unless payload_type

      schema_for_type(payload_type, schemas)
    end

    sig do
      params(
        signature: T::Private::Methods::Signature,
        schemas: T::Hash[String, T::Hash[String, T.untyped]]
      ).returns(T.nilable(T::Hash[String, T.untyped]))
    end
    def self.response_body_schema(signature:, schemas:)
      return_type = signature.return_type
      response_body_type = unwrap_response_body(return_type)
      schema_for_type(response_body_type, schemas) if response_body_type
    end

    sig { params(type: T.untyped).returns(T.untyped) }
    def self.unwrap_response_body(type)
      if type.respond_to?(:raw_type) && type.raw_type == App::Controllers::Response
        return nil
      end
      if type.respond_to?(:klass) && type.respond_to?(:type_params) && type.klass == App::Controllers::Response
        type.type_params.first
      else
        type
      end
    end

    sig { params(type: T.untyped).returns(T.untyped) }
    def self.extract_request_payload_type(type)
      return unless type.respond_to?(:klass) && type.respond_to?(:type_params)

      return unless type.klass == App::Controllers::Request

      payload_type = type.type_params.first
      return nil if payload_type.is_a?(T::Types::Anything)

      payload_type
    end

    sig do
      params(type: T.untyped, schemas: T::Hash[String, T::Hash[String, T.untyped]])
        .returns(T.nilable(T::Hash[String, T.untyped]))
    end
    def self.schema_for_type(type, schemas)
      case type
      when T::Types::Simple
        schema_for_simple(type, schemas)
      when Class
        schema_for_raw(type, schemas)
      when T::Types::TypedArray
        { "type" => "array", "items" => schema_for_type(type.type, schemas) }
      when T::Types::TypedHash
        { "type" => "object", "additionalProperties" => schema_for_type(type.value_type, schemas) }
      when T::Types::Union
        nullable, non_nil = split_nilable(type)
        schema = schema_for_type(non_nil, schemas)
        if schema && nullable
          schema.merge("nullable" => true)
        else
          schema
        end
      when T::Types::Anything
        {
          "oneOf" => [
            { "type" => "string" },
            { "type" => "integer" },
            { "type" => "number" },
            { "type" => "boolean" },
            { "type" => "object" },
            { "type" => "array" }
          ]
        }
      else
        if type.respond_to?(:raw_type)
          schema_for_raw(type.raw_type, schemas)
        else
          nil
        end
      end
    end

    sig do
      params(type: T::Types::Simple, schemas: T::Hash[String, T::Hash[String, T.untyped]])
        .returns(T::Hash[String, T.untyped])
    end
    def self.schema_for_simple(type, schemas)
      schema_for_raw(type.raw_type, schemas)
    end

    sig do
      params(raw: T.untyped, schemas: T::Hash[String, T::Hash[String, T.untyped]])
        .returns(T::Hash[String, T.untyped])
    end
    def self.schema_for_raw(raw, schemas)
      if raw.is_a?(Class) && raw <= T::Struct
        name = component_name(raw)
        schemas[name] ||= struct_schema(raw, schemas)
        { "$ref" => "#/components/schemas/#{name}" }
      elsif raw == String || raw == Symbol
        { "type" => "string" }
      elsif raw == Integer
        { "type" => "integer" }
      elsif raw == Float
        { "type" => "number", "format" => "float" }
      elsif raw == Numeric
        { "type" => "number" }
      elsif raw == TrueClass || raw == FalseClass || raw == T::Boolean
        { "type" => "boolean" }
      elsif raw == NilClass
        { "nullable" => true }
      else
        { "type" => "object" }
      end
    end

    sig do
      params(
        schema_ref: T.untyped,
        schemas: T::Hash[String, T::Hash[String, T.untyped]]
      ).returns(T.nilable(T::Hash[String, T.untyped]))
    end
    def self.schema_ref_for(schema_ref, schemas)
      if schema_ref.is_a?(Class) && schema_ref <= T::Struct
        name = component_name(schema_ref)
        schemas[name] ||= struct_schema(schema_ref, schemas)
        { "$ref" => "#/components/schemas/#{name}" }
      elsif schema_ref.is_a?(String)
        { "$ref" => "#/components/schemas/#{schema_ref}" }
      else
        nil
      end
    end

    sig do
      params(type: T::Types::Union).returns([T::Boolean, T.untyped])
    end
    def self.split_nilable(type)
      types = type.types
      nullable = types.any? { |entry| entry.respond_to?(:raw_type) && entry.raw_type == NilClass }
      non_nil = types.reject { |entry| entry.respond_to?(:raw_type) && entry.raw_type == NilClass }
      [nullable, non_nil.first]
    end

    sig { params(klass: T.class_of(T::Struct)).returns(String) }
    def self.component_name(klass)
      klass.name.split("::").last
    end

    sig do
      params(klass: T.class_of(T::Struct), schemas: T::Hash[String, T::Hash[String, T.untyped]])
        .returns(T::Hash[String, T.untyped])
    end
    def self.struct_schema(klass, schemas)
      props = klass.props
      properties = {}
      required = []
      props.each do |name, prop|
        prop_type = prop.respond_to?(:type) ? prop.type : prop[:type]
        optional = prop.respond_to?(:optional) ? prop.optional : prop[:optional]
        properties[name.to_s] = schema_for_type(prop_type, schemas) || {}
        required << name.to_s unless optional
      end
      schema = {
        "type" => "object",
        "properties" => properties
      }
      schema["required"] = required unless required.empty?
      schema
    end
    private_class_method :controllers
  end
end
