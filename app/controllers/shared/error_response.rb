# typed: true

require "sorbet-runtime"
require_relative "../../app"

class App::Controllers::ErrorResponse < T::Struct
  const :error, String
end
