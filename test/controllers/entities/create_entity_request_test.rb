# typed: true

require_relative "../../test_helper"
require_relative "../../../app/controllers/entities/create_entity_request"

class CreateEntityRequestTest < Minitest::Test
  extend T::Sig

  sig { void }
  def test_from_hash_builds_attributes
    payload = {
      "attributes" => [
        { "name" => "name", "value" => "Ana" },
        { "name" => "age", "value" => 30 }
      ]
    }

    request = App::Controllers::Entities::CreateEntityRequest.from_hash(payload)

    assert_equal 2, request.attributes.size
    first = T.must(request.attributes.first)
    last = T.must(request.attributes.last)

    assert_equal "name", first.name
    assert_equal "Ana", first.value
    assert_equal "age", last.name
    assert_equal 30, last.value
  end

  sig { void }
  def test_from_hash_rejects_missing_attributes
    error = assert_raises(App::Errors::ValidationError) do
      App::Controllers::Entities::CreateEntityRequest.from_hash({})
    end

    assert_equal "Invalid request payload", error.message
    assert_equal ["attributes is required"], error.details
  end

  sig { void }
  def test_from_hash_rejects_empty_attributes_array
    error = assert_raises(App::Errors::ValidationError) do
      App::Controllers::Entities::CreateEntityRequest.from_hash({ "attributes" => [] })
    end

    assert_equal "Invalid request payload", error.message
    assert_equal ["attributes is required"], error.details
  end

  sig { void }
  def test_from_hash_rejects_nil_attributes
    error = assert_raises(App::Errors::ValidationError) do
      App::Controllers::Entities::CreateEntityRequest.from_hash({ "attributes" => nil })
    end

    assert_equal "Invalid request payload", error.message
    assert_equal ["attributes is invalid"], error.details
  end

  sig { void }
  def test_from_hash_allows_wrong_attribute_identifiers
    payload = {
      "attributes" => [
        { "label" => "name", "data" => "Ana" }
      ]
    }

    error = assert_raises(App::Errors::ValidationError) do
      App::Controllers::Entities::CreateEntityRequest.from_hash(payload)
    end

    assert_equal "Invalid request payload", error.message
    assert_equal ["attributes[].name is required", "attributes[].value is required"], error.details.sort
  end
end
