# typed: true

require "sorbet-runtime"
require_relative "../../app"

class App::Controllers::Request < T::Struct
  extend T::Generic

  Payload = type_member

  const :params, T::Hash[String, String]
  const :json, T.nilable(Payload)
end
