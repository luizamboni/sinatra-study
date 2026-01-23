# typed: true

require "json"
require "rack/test"
require "securerandom"

require_relative "../test_helper"
require_relative "../../app/api/api"

class SwaggerTest < Minitest::Test
  include Rack::Test::Methods

  def app
    App::Api::AppApiRoutes
  end

  def json(body)
    JSON.parse(body)
  end

  def test_swagger_json_v1
    get "/swagger.json", {}, "HTTP_HOST" => "localhost"

    assert_equal 200, last_response.status
    assert_match(/application\/json/, last_response.headers["Content-Type"])

    payload = json(last_response.body)
    assert payload["paths"].key?("/schemas")
    assert payload["paths"].key?("/entities/{schema}")
  end

  def test_swagger_docs_v1
    get "/docs", {}, "HTTP_HOST" => "localhost"

    assert_equal 200, last_response.status
    assert_match(/text\/html/, last_response.headers["Content-Type"])
  end

  def test_swagger_json_v2
    get "/v2/swagger.json", {}, "HTTP_HOST" => "localhost"

    assert_equal 200, last_response.status
    assert_match(/application\/json/, last_response.headers["Content-Type"])

    payload = json(last_response.body)
    assert payload["paths"].key?("/v2/schemas")
    assert payload["paths"].key?("/v2/entities/{schema}")
  end

  def test_swagger_docs_v2
    get "/v2/docs", {}, "HTTP_HOST" => "localhost"

    assert_equal 200, last_response.status
    assert_match(/text\/html/, last_response.headers["Content-Type"])
  end

  def test_swagger_includes_custom_entity_schema
    get "/swagger.json", {}, "HTTP_HOST" => "localhost"

    assert_equal 200, last_response.status
    payload = json(last_response.body)
    schemas = payload.fetch("components").fetch("schemas")

    assert schemas.key?("CreateEntityRequest")
    assert schemas.key?("CreateSchemaRequest")
    assert schemas.key?("AttributePayload")
    assert schemas.key?("FieldPayload")
  end

  def test_dynamic_schema_swagger
    schema_name = "product-#{SecureRandom.hex(4)}"
    post(
      "/schemas",
      JSON.generate(
        {
          name: schema_name,
          fields: [
            { name: "title", type: "string" },
            { name: "price", type: "integer" }
          ]
        }
      ),
      "CONTENT_TYPE" => "application/json",
      "HTTP_HOST" => "localhost"
    )
    assert_equal 201, last_response.status

    get "/#{schema_name}/swagger.json", {}, "HTTP_HOST" => "localhost"
    assert_equal 200, last_response.status
    payload = json(last_response.body)
    paths = payload.fetch("paths")
    assert paths.key?("/entities/#{schema_name}")

    schemas = payload.fetch("components").fetch("schemas")
    attribute_schema = schemas.values.find { |schema| schema["oneOf"] }
    ref = attribute_schema["oneOf"].find do |entry|
      name_schema = entry.dig("properties", "name")
      name_schema && Array(name_schema["enum"]).include?("title")
    end
    assert ref
  end
end
