# typed: true

require "sorbet-runtime"
require_relative "../../app"

module App::Controllers::Shared
  class ErrorResponse < T::Struct
    const :error, String
    const :details, T.nilable(T::Array[String]), default: nil
  end
end
