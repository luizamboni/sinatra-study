# typed: true

require "json"
require "sorbet-runtime"
require_relative "../app"
require_relative "../controllers/shared/request"

module App::Api::Helpers
  extend T::Sig
  extend T::Helpers
  requires_ancestor { Sinatra::Base }

  sig { returns(App::Services::DynamicEntityService) }
  def dynamic_entity_service
    T.cast(T.unsafe(self).settings.dynamic_entity_service, App::Services::DynamicEntityService)
  end

  sig { returns(T::Hash[String, T.untyped]) }
  def require_json_object
    request = T.unsafe(self).request
    body = request.body&.read.to_s
    Kernel.raise ArgumentError, "Request body is empty" if body.strip.empty?

    parsed = JSON.parse(body)
    unless parsed.is_a?(Hash)
      Kernel.raise ArgumentError, "Request body must be a JSON object"
    end
    parsed
  rescue JSON::ParserError
    Kernel.raise ArgumentError, "Request body must be valid JSON"
  ensure
    request.body.rewind if request.body.respond_to?(:rewind)
  end

  sig do
    params(coerce_class: T.untyped).returns(App::Controllers::Request[T.untyped])
  end
  def build_request(coerce_class: nil)
    json = T.let(nil, T.untyped)
    if coerce_class && coerce_class.respond_to?(:from_hash)
      json = T.unsafe(coerce_class).from_hash(require_json_object)
    end
    params_hash = T.cast(T.unsafe(self).params, T::Hash[T.untyped, T.untyped])
    App::Controllers::Request.new(
      params: params_hash.transform_values(&:to_s),
      json: json
    )
  rescue JSON::ParserError
    Kernel.raise ArgumentError, "Request body must be valid JSON"
  end

  sig { params(payload: T.untyped, status_code: Integer).returns(String) }
  def json_response(payload, status_code = 200)
    T.unsafe(self).content_type :json
    T.unsafe(self).status status_code
    JSON.generate(payload)
  end

  sig { params(payload: T.untyped).returns(T.untyped) }
  def normalize_payload(payload)
    case payload
    when T::Struct
      if payload.respond_to?(:to_h)
        normalize_payload(T.unsafe(payload).to_h)
      elsif payload.respond_to?(:serialize)
        normalize_payload(payload.serialize)
      else
        payload
      end
    when Array
      payload.map { |item| normalize_payload(item) }
    when Hash
      payload.each_with_object({}) do |(key, value), acc|
        acc[key] = normalize_payload(value)
      end
    else
      payload
    end
  end
end
