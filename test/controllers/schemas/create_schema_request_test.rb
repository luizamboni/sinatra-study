# typed: true

require_relative "../../test_helper"
require_relative "../../../app/controllers/schemas/create_schema_request"

class CreateSchemaRequestTest < Minitest::Test
  extend T::Sig

  sig { void }
  def test_from_hash_builds_fields
    payload = {
      "name" => "user",
      "fields" => [
        { "name" => "name", "type" => "string" },
        { "name" => "age", "type" => "integer" }
      ]
    }

    request = App::Controllers::Schemas::CreateSchemaRequest.from_hash(payload)

    assert_equal "user", request.name
    assert_equal 2, request.fields.size
    first = T.must(request.fields.first)
    last = T.must(request.fields.last)

    assert_equal "name", first.name
    assert_equal "string", first.type
    assert_equal "age", last.name
    assert_equal "integer", last.type
  end

  sig { void }
  def test_from_hash_rejects_missing_fields
    error = assert_raises(Dry::Struct::Error) do
      App::Controllers::Schemas::CreateSchemaRequest.from_hash({ "name" => "user" })
    end

    assert_match(/fields/i, error.message)
  end

  sig { void }
  def test_from_hash_rejects_nil_fields
    error = assert_raises(Dry::Struct::Error) do
      App::Controllers::Schemas::CreateSchemaRequest.from_hash({ "name" => "user", "fields" => nil })
    end

    assert_match(/fields/i, error.message)
  end

  sig { void }
  def test_from_hash_rejects_empty_fields_array
    error = assert_raises(Dry::Struct::Error) do
      App::Controllers::Schemas::CreateSchemaRequest.from_hash({ "name" => "user", "fields" => [] })
    end

    assert_match(/fields/i, error.message)
  end

  sig { void }
  def test_from_hash_allows_wrong_schema_identifier
    payload = {
      "identifier" => "user",
      "fields" => [
        { "name" => "name", "type" => "string" }
      ]
    }

    error = assert_raises(Dry::Struct::Error) do
      App::Controllers::Schemas::CreateSchemaRequest.from_hash(payload)
    end

    assert_match(/name/i, error.message)
  end

  sig { void }
  def test_from_hash_allows_wrong_field_identifiers
    payload = {
      "name" => "user",
      "fields" => [
        { "label" => "name", "kind" => "string" }
      ]
    }

    error = assert_raises(Dry::Struct::Error) do
      App::Controllers::Schemas::CreateSchemaRequest.from_hash(payload)
    end

    assert_match(/name/i, error.message)
  end
end
