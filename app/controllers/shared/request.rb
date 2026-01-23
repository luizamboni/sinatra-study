# typed: true

require "sorbet-runtime"
require_relative "../../app"

module App::Controllers::Shared
  class Request < T::Struct
    extend T::Generic

    Payload = type_member

    const :params, T::Hash[String, String]
    const :json, T.nilable(Payload)
  end
end
