# typed: true
# Sorbet uses this magic comment to enable type checking for the file.

require "sorbet-runtime"
require_relative "../app"
require_relative "dependency_builder"

module App::App
  extend T::Sig


  sig { returns(DependencyBuilder::Container) }
  def self.build
    DependencyBuilder.build(
      repository_class: ::App::Infrastructure::Repository
    )
  end

  # Sorbet signatures document and check method return types.
  sig { returns(DependencyBuilder::Container) }
  def self.start
    self.build
  end
end
