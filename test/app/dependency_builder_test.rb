# typed: true

require_relative "../test_helper"
require_relative "../../app/app/dependency_builder"
require_relative "../../app/controllers/shared/request"

class DependencyBuilderTest < Minitest::Test
  extend T::Sig

  sig { void }
  def setup
    @container = T.let(
      App::App::DependencyBuilder.build(repository_class: App::Infrastructure::Repository),
      App::App::DependencyBuilder::Container
    )
  end

  sig { void }
  def test_memoizes_services
    assert_same @container.dynamic_entity_service, @container.dynamic_entity_service
    assert_same @container.schemas_controller, @container.schemas_controller
    assert_same @container.entities_controller, @container.entities_controller
  end

  sig { void }
  def test_controllers_share_wired_service
    @container.dynamic_entity_service.define_schema(
      name: :user,
      fields: [App::Domain::Field.new(name: :name, type: :string)]
    )

    @container.dynamic_entity_service.create_entity(
      schema_name: :user,
      attributes: [App::Domain::Attribute.new(name: :name, value: "Ana")]
    )

    schemas_response = @container.schemas_controller.index(
      request: App::Controllers::Request.new(params: {}, json: nil)
    )
    assert_equal 1, schemas_response.body.schemas.size
    assert_equal "user", schemas_response.body.schemas.first.name

    entities_response = @container.entities_controller.index(
      request: App::Controllers::Request.new(params: { "schema" => "user" }, json: nil)
    )
    assert_equal "user", entities_response.body.schema
    assert_equal 1, entities_response.body.entities.size
  end
end
