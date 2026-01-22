# typed: true
# Sorbet signatures help keep tests consistent with runtime expectations.

require_relative "../test_helper"

class EntityServiceTest < Minitest::Test
  extend T::Sig

  @service = T.let(nil, T.nilable(App::Services::EntityService))

  sig { void }
  def setup
    @service = T.let(App::Services::EntityService.new, T.nilable(App::Services::EntityService))
  end

  sig { returns(App::Services::EntityService) }
  def service
    T.must(@service)
  end

  sig { void }
  def test_add_entity
    entity = App::Domain::Entity.new(
      schema_name: :user,
      attributes: [App::Domain::Attribute.new(name: :name, value: "Ana")]
    )

    result = service.add_entity(entity: entity)

    assert_equal entity, result
    assert_equal [entity], service.all
  end

  sig { void }
  def test_entities_for_filters_by_schema
    user = App::Domain::Entity.new(
      schema_name: :user,
      attributes: [App::Domain::Attribute.new(name: :name, value: "Ana")]
    )
    post = App::Domain::Entity.new(
      schema_name: :post,
      attributes: [App::Domain::Attribute.new(name: :title, value: "Hello")]
    )

    service.add_entity(entity: user)
    service.add_entity(entity: post)

    assert_equal [user], service.entities_for(schema_name: :user)
    assert_equal [post], service.entities_for(schema_name: :post)
  end
end
