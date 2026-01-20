# typed: true
# Sorbet signatures help keep tests consistent with runtime expectations.

require_relative "../test_helper"

class EntityTest < Minitest::Test
  extend T::Sig

  sig { void }
  def test_initializes_with_string_schema_name
    entity = App::Domain::Entity.new(
      schema_name: :user,
      attributes: [App::Domain::Attribute.new(name: :name, value: "Ana")]
    )

    assert_equal "user", entity.schema_name
  end

  sig { void }
  def test_preserves_attributes
    attributes = [
      App::Domain::Attribute.new(name: :name, value: "Ana"),
      App::Domain::Attribute.new(name: :age, value: 30)
    ]

    entity = App::Domain::Entity.new(schema_name: "user", attributes: attributes)

    assert_equal attributes, entity.attributes
  end
end
