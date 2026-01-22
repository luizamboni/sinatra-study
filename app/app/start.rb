# typed: true
# Sorbet uses this magic comment to enable type checking for the file.

require "sorbet-runtime"
require_relative "../app"
require_relative "dependency_builder"
require_relative "./seed"

module App::App
  extend T::Sig

  sig { returns(App::App::DependencyBuilder::Container) }
  def self.build
    DependencyBuilder.build(
      repository_class: App::Infrastructure::Repository
    )
  end

  # Sorbet signatures document and check method return types.
  sig { returns(T::Hash[Symbol, T::Array[App::Domain::Entity]]) }
  def self.start
    container = self.build
    schema_names = Seed.run(container: container)

    {
      users: container.dynamic_entity_service.entities_for(schema_name: T.must(schema_names[:users])),
      posts: container.dynamic_entity_service.entities_for(schema_name: T.must(schema_names[:posts]))
    }
  end
end
