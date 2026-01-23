# typed: true

require "dry-types"

module App::Types
  include Dry.Types(default: :strict)
end
