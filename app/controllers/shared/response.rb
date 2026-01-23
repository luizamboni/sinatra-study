# typed: true

require "sorbet-runtime"
require_relative "../../app"

module App::Controllers::Shared
  class Response < T::Struct
    extend T::Generic

    Body = type_member

    const :status, Integer
    const :body, Body
  end
end
