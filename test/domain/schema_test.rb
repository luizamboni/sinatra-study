# typed: true
# Sorbet signatures help keep tests consistent with runtime expectations.

require_relative "../test_helper"

class SchemaTest < Minitest::Test
  extend T::Sig

  sig { void }
  def test_normalizes_field_names_and_types
    schema = App::Domain::Schema.new(
      name: "user",
      fields: [
        App::Domain::Field.new(name: "name", type: "string"),
        App::Domain::Field.new(name: :age, type: :integer)
      ]
    )

    assert_equal({ name: :string, age: :integer }, schema.fields)
  end

  sig { void }
  def test_rejects_empty_fields_array
    error = assert_raises(ArgumentError) do
      App::Domain::Schema.new(name: :user, fields: [])
    end

    assert_match(/Fields must be a non-empty Array/, error.message)
  end

  sig { void }
  def test_rejects_blank_field_name
    error = assert_raises(ArgumentError) do
      App::Domain::Schema.new(
        name: :user,
        fields: [App::Domain::Field.new(name: " ", type: :string)]
      )
    end

    assert_match(/Field name must be present/, error.message)
  end

  sig { void }
  def test_rejects_class_field_types
    error = assert_raises(TypeError) do
      App::Domain::Schema.new(
        name: :user,
        fields: [App::Domain::Field.new(name: :name, type: String)]
      )
    end

    assert_match(/Expected type T\.any\(String, Symbol\)/, error.message)
  end

  sig { void }
  def test_rejects_non_field_entries
    error = assert_raises(ArgumentError) do
      App::Domain::Schema.new(name: :user, fields: [T.unsafe({})])
    end

    assert_match(/Each field must be an App::Domain::Field/, error.message)
  end
end
