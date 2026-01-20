# typed: true
# Sorbet signatures help keep tests consistent with runtime expectations.

require_relative "../test_helper"

class AttributeTest < Minitest::Test
  extend T::Sig

  sig { void }
  def test_initializes_with_symbol_name
    attribute = App::Domain::Attribute.new(name: "name", value: "Ana")

    assert_equal :name, attribute.name
    assert_equal "Ana", attribute.value
  end
end
