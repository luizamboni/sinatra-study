# typed: true

require "sorbet-runtime"
require_relative "../app"

class App::Controllers::Base
  extend T::Sig

  @open_api_routes = T.let({}, T::Hash[String, T::Hash[String, T::Hash[String, T.untyped]]])

  class << self
    extend T::Sig

    def inherited(subclass)
      super
      subclass.instance_variable_set(:@open_api_routes, {})
    end

    sig { returns(T::Hash[String, T::Hash[String, T::Hash[String, T.untyped]]]) }
    def open_api_routes
      @open_api_routes
    end

    sig do
      params(
        path: String,
        method: String,
        summary: String,
        action: Symbol,
        responses: T::Hash[String, T::Hash[String, T.untyped]],
        parameters: T.nilable(T::Array[T::Hash[String, T.untyped]]),
        request_body: T.untyped,
        response_body: T.untyped
      ).void
    end
    def register_route(path:, method:, summary:, action:, responses:, parameters: nil, request_body: nil, response_body: nil)
      normalized_method = method.downcase
      routes = T.let(@open_api_routes, T::Hash[String, T::Hash[String, T::Hash[String, T.untyped]]])
      path_routes = routes[path]
      unless path_routes
        path_routes = {}
        routes[path] = path_routes
      end
      entry = {
        "summary" => summary,
        "responses" => responses,
        "x-action" => action.to_s
      }
      entry["parameters"] = parameters if parameters && !parameters.empty?
      entry["request_body"] = request_body if request_body
      entry["response_body"] = response_body if response_body
      path_routes[normalized_method] = entry
    end
  end
end
