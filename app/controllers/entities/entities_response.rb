# typed: true

require "sorbet-runtime"
require_relative "../../app"
require_relative "entity_item"

module App::Controllers::Entities
  class EntitiesResponse < T::Struct
    const :schema, String
    const :entities, T::Array[EntityItem]
  end
end
