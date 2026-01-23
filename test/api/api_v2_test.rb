# typed: true

require "json"
require "rack/test"
require "securerandom"

require_relative "../test_helper"
require_relative "../../app/api/api"

class ApiV2Test < Minitest::Test
  include Rack::Test::Methods

  def app
    App::Api::AppApiRoutes
  end

  def json(body)
    JSON.parse(body)
  end

  def post_json(path, payload)
    post(
      path,
      JSON.generate(payload),
      "CONTENT_TYPE" => "application/json",
      "HTTP_HOST" => "localhost"
    )
  end

  def test_creates_schema_and_entity
    schema_name = "user-#{SecureRandom.hex(4)}"
    post_json(
      "/v2/schemas",
      {
        name: schema_name,
        fields: [
          { name: "name", type: "string" },
          { name: "age", type: "integer" }
        ]
      }
    )
    assert_equal 201, last_response.status

    post_json(
      "/v2/entities/#{schema_name}",
      {
        attributes: [
          { name: "name", value: "Ana" },
          { name: "age", value: 30 }
        ]
      }
    )

    assert_equal 200, last_response.status
    entity = json(last_response.body)
    assert_equal schema_name, entity["schema"]
    assert_equal(
      [
        { "name" => "name", "value" => "Ana" },
        { "name" => "age", "value" => 30 }
      ],
      entity["attributes"]
    )
  end

  def test_get_entities
    schema_name = "post-#{SecureRandom.hex(4)}"
    post_json(
      "/v2/schemas",
      {
        name: schema_name,
        fields: [
          { name: "title", type: "string" }
        ]
      }
    )

    post_json(
      "/v2/entities/#{schema_name}",
      {
        attributes: [
          { name: "title", value: "Hello" }
        ]
      }
    )

    get "/v2/entities/#{schema_name}", {}, "HTTP_HOST" => "localhost"

    assert_equal 200, last_response.status
    payload = json(last_response.body)
    assert_equal schema_name, payload["schema"]
    assert_equal(
      [
        { "attributes" => [{ "name" => "title", "value" => "Hello" }] }
      ],
      payload["entities"]
    )
  end

  def test_rejects_invalid_entity
    post_json(
      "/v2/schemas",
      {
        name: "user",
        fields: [
          { name: "name", type: "string" }
        ]
      }
    )

    post_json(
      "/v2/entities/user",
      {
        attributes: [
          { name: "name", value: 123 }
        ]
      }
    )

    assert_equal 422, last_response.status
    payload = json(last_response.body)
    assert_equal "Invalid request payload", payload["error"]
    assert_equal ["Field name expected :string, got Integer"], payload["details"]
  end

  def test_rejects_invalid_nested_attributes
    schema_name = "user-#{SecureRandom.hex(4)}"
    post_json(
      "/v2/schemas",
      {
        name: schema_name,
        fields: [
          { name: "name", type: "string" }
        ]
      }
    )

    post_json(
      "/v2/entities/#{schema_name}",
      {
        attributes: [
          { value: "Ana" }
        ]
      }
    )

    assert_equal 422, last_response.status
    payload = json(last_response.body)
    assert_equal "Invalid request payload", payload["error"]
    assert_equal ["attributes[].name is required"], payload["details"]
  end
end
