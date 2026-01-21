# typed: true

require "sinatra/base"
require "sorbet-runtime"
require_relative "../app"
require_relative "../infrastructure/repository"
require_relative "../infrastructure/sqlite_repository"
require_relative "../domain/schema"
require_relative "../domain/entity"
require_relative "../services/schema_service"
require_relative "../services/entity_service"
require_relative "../services/dynamic_entity_service"
require_relative "../app/dependency_builder"
require_relative "open_api"


module App::Api::SinatraSetup
  extend T::Sig

  sig { params(app: T.class_of(Sinatra::Base)).void }
  def self.configure(app)
    app.set :show_exceptions, false
    app.set :protection, false
    app.set :allow_hosts, ["localhost", "127.0.0.1", "[::1]"]
  end
end
