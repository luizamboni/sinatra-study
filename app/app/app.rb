# typed: false

require "json"
require "sinatra/base"
require_relative "../app"
require_relative "../controllers/shared/request"
require_relative "../controllers/shared/response"

module App::App
  class App
    def initialize(sinatra_app, name: nil, version: nil, openapi_proc: nil, docs_proc: nil)
      @sinatra_app = sinatra_app
      @contracts = []
      @name = name
      @version = version
      @openapi_proc = openapi_proc
      @docs_proc = docs_proc
    end

    attr_reader :sinatra_app

    def get(path, request_class = nil, response_classes = [], &block)
      define_route(:get, path, request_class, response_classes, &block)
    end

    def post(path, request_class = nil, response_classes = [], &block)
      define_route(:post, path, request_class, response_classes, &block)
    end

    def put(path, request_class = nil, response_classes = [], &block)
      define_route(:put, path, request_class, response_classes, &block)
    end

    def patch(path, request_class = nil, response_classes = [], &block)
      define_route(:patch, path, request_class, response_classes, &block)
    end

    def delete(path, request_class = nil, response_classes = [], &block)
      define_route(:delete, path, request_class, response_classes, &block)
    end

    def contracts
      @contracts.dup
    end

    def swagger_path
      segments = []
      segments << @name if @name
      segments << @version if @version
      "/" + (segments + ["swagger.json"]).join("/")
    end

    def docs_path
      segments = []
      segments << @name if @name
      segments << @version if @version
      "/" + (segments + ["docs"]).join("/")
    end

    def swagger_spec
      return nil unless @openapi_proc
      spec = @openapi_proc.call
      prefix = swagger_prefix
      if prefix && spec.is_a?(Hash) && spec["paths"].is_a?(Hash)
        spec = spec.dup
        spec["paths"] = contract_paths_for_spec(spec, prefix)
      end
      spec
    end

    def docs_html
      return nil unless @docs_proc
      @docs_proc.call(swagger_path)
    end

    def configure
      yield(@sinatra_app) if block_given?
    end

    def configure_defaults
      configure do |app|
        app.set :show_exceptions, false
        app.set :protection, false
        app.set :allow_hosts, ["localhost", "127.0.0.1", "[::1]"]
      end
    end

    private

    def swagger_prefix
      return "/#{@version}" if @version
      return "/#{@name}" if @name
      nil
    end

    def contract_paths_for_spec(spec, prefix)
      return {} if @contracts.empty?

      base_paths = spec["paths"]
      @contracts.each_with_object({}) do |contract, acc|
        contract_path = contract[:path]
        base_path = contract_path.sub(prefix, "")
        base_path = base_path.gsub(/:([a-zA-Z_]\w*)/, '{\1}')
        verb = contract[:verb].to_s
        next unless base_paths[base_path].is_a?(Hash)
        next unless base_paths[base_path][verb]

        acc[contract_path] ||= {}
        acc[contract_path][verb] = base_paths[base_path][verb]
      end
    end

    def define_route(verb, path, request_class, response_classes, &block)
      @contracts << {
        verb: verb,
        path: path,
        request: request_class,
        responses: response_classes
      }

      wrapper = self
      @sinatra_app.send(verb, path) do
        request_payload = request_class ? wrapper.require_json_object(request) : nil
        if request_class && request_class.respond_to?(:from_hash)
          request_payload = request_class.from_hash(request_payload)
        end

        request_obj = wrapper.build_request(params, request_payload)

        result = if block.arity <= 0
          instance_exec(&block)
        elsif block.arity == 1
          arg = request_class ? request_payload : request_obj
          instance_exec(arg, &block)
        else
          instance_exec(request_obj, request_payload, &block)
        end

        response_status = 200
        response_body = result

        if result.is_a?(::App::Controllers::Response)
          response_status = result.status
          response_body = result.body
        end

        if response_classes && !response_classes.empty?
          unless response_classes.any? { |klass| response_body.is_a?(klass) }
            raise ArgumentError, "Expected response to be one of #{response_classes.map(&:name).join(", ")}, got #{response_body.class}"
          end
        end

        content_type :json
        status response_status
        JSON.generate(wrapper.normalize_payload(response_body))
      end
    end

    def normalize_payload(payload)
      if payload.respond_to?(:serialize)
        normalize_payload(payload.serialize)
      elsif payload.is_a?(Array)
        payload.map { |item| normalize_payload(item) }
      elsif payload.is_a?(Hash)
        payload.each_with_object({}) do |(key, value), acc|
          acc[key] = normalize_payload(value)
        end
      elsif payload.respond_to?(:to_h)
        normalize_payload(payload.to_h)
      else
        payload
      end
    end

    def require_json_object(rack_request)
      body = rack_request.body&.read.to_s
      raise ArgumentError, "Request body is empty" if body.strip.empty?

      parsed = JSON.parse(body)
      unless parsed.is_a?(Hash)
        raise ArgumentError, "Request body must be a JSON object"
      end
      parsed
    rescue JSON::ParserError
      raise ArgumentError, "Request body must be valid JSON"
    ensure
      rack_request.body.rewind if rack_request.body.respond_to?(:rewind)
    end

    def build_request(params_hash, request_payload)
      params_hash = params_hash.to_h.transform_values(&:to_s)
      ::App::Controllers::Request.new(params: params_hash, json: request_payload)
    end

    public :require_json_object, :build_request, :normalize_payload
  end
end
