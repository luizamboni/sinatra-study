# typed: true
# Sorbet signatures help keep tests consistent with runtime expectations.

require_relative "../test_helper"

class SchemaServiceTest < Minitest::Test
  extend T::Sig

  sig { void }
  def setup
    @service = T.let(App::Services::SchemaService.new, App::Services::SchemaService)
  end

  sig { void }
  def test_define_schema_and_find_schema
    schema = @service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :name, type: :string)
      ]
    )

    found = @service.find_schema(name: :user)

    assert_equal schema, found
    assert_equal "user", found&.name
  end

  sig { void }
  def test_schemas_returns_all
    user = @service.define_schema(
      name: :user,
      fields: [
        App::Domain::Field.new(name: :name, type: :string)
      ]
    )
    post = @service.define_schema(
      name: :post,
      fields: [
        App::Domain::Field.new(name: :title, type: :string)
      ]
    )

    assert_equal [user, post], @service.schemas
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
