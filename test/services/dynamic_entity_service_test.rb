# typed: true
# Sorbet signatures help keep tests consistent with runtime expectations.

require_relative "../test_helper"

class DynamicEntityServiceTest < Minitest::Test
  extend T::Sig

  @service = T.let(nil, T.nilable(App::Services::DynamicEntityService))

  # Use T.let to declare the instance variable type for Sorbet.
  sig { void }
  def setup
    @service = T.let(App::Services::DynamicEntityService.new, T.nilable(App::Services::DynamicEntityService))
  end

  sig { returns(App::Services::DynamicEntityService) }
  def service
    T.must(@service)
  end

  sig { void }
  def test_define_schema_and_create_entity
    attributes = [
      App::Domain::Attribute.new(name: :name, value: "Ana"),
      App::Domain::Attribute.new(name: :age, value: 30),
      App::Domain::Attribute.new(name: :admin, value: false)
    ]

    service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :name, type: :string),
        App::Domain::Field.new(name: :age, type: :integer),
        App::Domain::Field.new(name: :admin, type: :boolean)
      ]
    )

    entity = service.create_entity(
      schema_name: :user,
      attributes: attributes
    )

    assert_equal "user", entity.schema_name
    assert_equal attributes, entity.attributes
  end

  sig { void }
  def test_rejects_missing_fields
    service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :name, type: :string),
        App::Domain::Field.new(name: :age, type: :integer)
      ]
    )

    error = assert_raises(App::Errors::ValidationError) do
      service.create_entity(
        schema_name: :user,
        attributes: [
          App::Domain::Attribute.new(name: :name, value: "Ana")
        ]
      )
    end

    assert_equal "Invalid request payload", error.message
    assert_equal ["Missing required field: age"], error.details
  end

  sig { void }
  def test_rejects_unknown_fields
    service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :name, type: :string)
      ]
    )

    error = assert_raises(App::Errors::ValidationError) do
      service.create_entity(
        schema_name: :user,
        attributes: [
          App::Domain::Attribute.new(name: :name, value: "Ana"),
          App::Domain::Attribute.new(name: :extra, value: "nope")
        ]
      )
    end

    assert_equal "Invalid request payload", error.message
    assert_equal ["Unknown fields: extra"], error.details
  end

  sig { void }
  def test_rejects_wrong_type
    service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :age, type: :integer)
      ]
    )

    error = assert_raises(App::Errors::ValidationError) do
      service.create_entity(
        schema_name: :user,
        attributes: [
          App::Domain::Attribute.new(name: :age, value: "30")
        ]
      )
    end

    assert_equal "Invalid request payload", error.message
    assert_equal ["Field age expected :integer, got String"], error.details
  end

  sig { void }
  def test_rejects_non_attribute_entries
    service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :name, type: :string)
      ]
    )

    error = assert_raises(App::Errors::ValidationError) do
      service.create_entity(schema_name: :user, attributes: [T.unsafe({})])
    end

    assert_equal "Invalid request payload", error.message
    assert_equal ["Each attribute must be an App::Domain::Attribute"], error.details
  end

  sig { void }
  def test_rejects_nil_value
    service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :name, type: :string)
      ]
    )

    error = assert_raises(App::Errors::ValidationError) do
      service.create_entity(
        schema_name: :user,
        attributes: [
          App::Domain::Attribute.new(name: :name, value: nil)
        ]
      )
    end

    assert_equal "Invalid request payload", error.message
    assert_equal ["Field name expected :string, got NilClass"], error.details
  end

  sig { void }
  def test_rejects_duplicate_schema
    service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :name, type: :string)
      ]
    )

    error = assert_raises(App::Errors::ValidationError) do
      service.define_schema(
        name: :user,
        fields: [
          App::Domain::Field.new(name: :name, type: :string)
        ]
      )
    end

    assert_equal "Invalid request payload", error.message
    assert_equal ["Schema already defined: user"], error.details
  end
end
