# typed: true

require "sorbet-runtime"
require_relative "../../app"

module App::Controllers::Schemas
  class FieldPayload < T::Struct
    const :name, String
    const :type, String
  end
end
