# typed: true
# Sorbet uses this magic comment to enable type checking for the file.

require "sorbet-runtime"
require_relative "../app"
require_relative "dependency_builder"
require_relative "../domain/field"
require_relative "../domain/attribute"

module App::App::Seed
  extend T::Sig

  sig do
    params(container: App::App::DependencyBuilder::Container)
      .returns(T::Hash[Symbol, Symbol])
  end
  
  def self.run(container:)
    service = container.dynamic_entity_service
    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    user_schema = :"user_#{timestamp}"
    post_schema = :"post_#{timestamp}"
    service.define_schema(
      name: user_schema,
      fields: [
        App::Domain::Field.new(name: :name, type: :string),
        App::Domain::Field.new(name: :age, type: :integer),
        App::Domain::Field.new(name: :admin, type: :boolean)
      ]
    )
    service.define_schema(
      name: post_schema,
      fields: [
        App::Domain::Field.new(name: :title, type: :string),
        App::Domain::Field.new(name: :body, type: :string),
        App::Domain::Field.new(name: :published, type: :boolean)
      ]
    )

    service.create_entity(
      schema_name: user_schema,
      attributes: [
        App::Domain::Attribute.new(name: :name, value: "Ana"),
        App::Domain::Attribute.new(name: :age, value: 30),
        App::Domain::Attribute.new(name: :admin, value: false)
      ]
    )
    service.create_entity(
      schema_name: user_schema,
      attributes: [
        App::Domain::Attribute.new(name: :name, value: "Rui"),
        App::Domain::Attribute.new(name: :age, value: 42),
        App::Domain::Attribute.new(name: :admin, value: true)
      ]
    )
    service.create_entity(
      schema_name: post_schema,
      attributes: [
        App::Domain::Attribute.new(name: :title, value: "Hello"),
        App::Domain::Attribute.new(name: :body, value: "First post"),
        App::Domain::Attribute.new(name: :published, value: true)
      ]
    )
    service.create_entity(
      schema_name: post_schema,
      attributes: [
        App::Domain::Attribute.new(name: :title, value: "Draft"),
        App::Domain::Attribute.new(name: :body, value: "Work in progress"),
        App::Domain::Attribute.new(name: :published, value: false)
      ]
    )

    { users: user_schema, posts: post_schema }
  end
end
