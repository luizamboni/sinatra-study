# typed: true

require "json"
require "rack/test"

require_relative "../test_helper"
require_relative "../../app/api/api"

class ApiTest < Minitest::Test
  include Rack::Test::Methods

  def app
    App::Api::AppApiRoutes
  end

  def setup
    App::Api::SinatraSetup.configure(app)
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
    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    schema_name = "user-#{timestamp}"
    post_json(
      "/schemas",
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
      "/entities/#{schema_name}",
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
    post_json(
      "/schemas",
      {
        name: "post",
        fields: [
          { name: "title", type: "string" }
        ]
      }
    )

    post_json(
      "/entities/post",
      {
        attributes: [
          { name: "title", value: "Hello" }
        ]
      }
    )

    get "/entities/post", {}, "HTTP_HOST" => "localhost"

    assert_equal 200, last_response.status
    payload = json(last_response.body)
    assert_equal "post", payload["schema"]
    assert_equal(
      [
        { "attributes" => [{ "name" => "title", "value" => "Hello" }] }
      ],
      payload["entities"]
    )
  end

  def test_rejects_invalid_entity
    post_json(
      "/schemas",
      {
        name: "user",
        fields: [
          { name: "name", type: "string" }
        ]
      }
    )

    post_json(
      "/entities/user",
      {
        attributes: [
          { name: "name", value: 123 }
        ]
      }
    )

    assert_equal 422, last_response.status
    assert_match(/Field name expected/, json(last_response.body)["error"])
  end
end
