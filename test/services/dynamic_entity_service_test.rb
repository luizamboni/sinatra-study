# typed: true
# Sorbet signatures help keep tests consistent with runtime expectations.

require_relative "../test_helper"

class DynamicEntityServiceTest < Minitest::Test
  extend T::Sig

  # Use T.let to declare the instance variable type for Sorbet.
  sig { void }
  def setup
    @service = T.let(App::Services::DynamicEntityService.new, App::Services::DynamicEntityService)
  end

  sig { void }
  def test_define_schema_and_create_entity
    attributes = [
      App::Domain::Attribute.new(name: :name, value: "Ana"),
      App::Domain::Attribute.new(name: :age, value: 30),
      App::Domain::Attribute.new(name: :admin, value: false)
    ]

    @service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :name, type: :string),
        App::Domain::Field.new(name: :age, type: :integer),
        App::Domain::Field.new(name: :admin, type: :boolean)
      ]
    )

    entity = @service.create_entity(
      schema_name: :user,
      attributes: attributes
    )

    assert_equal "user", entity.schema_name
    assert_equal attributes, entity.attributes
  end

  sig { void }
  def test_rejects_missing_fields
    @service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :name, type: :string),
        App::Domain::Field.new(name: :age, type: :integer)
      ]
    )

    error = assert_raises(ArgumentError) do
      @service.create_entity(
        schema_name: :user,
        attributes: [
          App::Domain::Attribute.new(name: :name, value: "Ana")
        ]
      )
    end

    assert_match(/Missing required field: age/, error.message)
  end

  sig { void }
  def test_rejects_unknown_fields
    @service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :name, type: :string)
      ]
    )

    error = assert_raises(ArgumentError) do
      @service.create_entity(
        schema_name: :user,
        attributes: [
          App::Domain::Attribute.new(name: :name, value: "Ana"),
          App::Domain::Attribute.new(name: :extra, value: "nope")
        ]
      )
    end

    assert_match(/Unknown fields: extra/, error.message)
  end

  sig { void }
  def test_rejects_wrong_type
    @service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :age, type: :integer)
      ]
    )

    error = assert_raises(ArgumentError) do
      @service.create_entity(
        schema_name: :user,
        attributes: [
          App::Domain::Attribute.new(name: :age, value: "30")
        ]
      )
    end

    assert_match(/Field age expected/, error.message)
  end

  sig { void }
  def test_rejects_non_attribute_entries
    @service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :name, type: :string)
      ]
    )

    error = assert_raises(ArgumentError) do
      @service.create_entity(schema_name: :user, attributes: [T.unsafe({})])
    end

    assert_match(/Each attribute must be an App::Domain::Attribute/, error.message)
  end

  sig { void }
  def test_rejects_nil_value
    @service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :name, type: :string)
      ]
    )

    error = assert_raises(ArgumentError) do
      @service.create_entity(
        schema_name: :user,
        attributes: [
          App::Domain::Attribute.new(name: :name, value: nil)
        ]
      )
    end

    assert_match(/Field name expected/, error.message)
  end

  sig { void }
  def test_rejects_duplicate_schema
    @service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :name, type: :string)
      ]
    )

    error = assert_raises(ArgumentError) do
      @service.define_schema(
        name: :user,
        fields: [
          App::Domain::Field.new(name: :name, type: :string)
        ]
      )
    end

    assert_match(/Schema already defined: user/, error.message)
  end
end
