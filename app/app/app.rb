# typed: false

require "json"
require "sinatra/base"
require_relative "../app"
require_relative "../api/open_api"
require_relative "../controllers/shared/request"
require_relative "../controllers/shared/response"
require_relative "../controllers/shared/error_response"

module App::App
  class App
    def initialize(sinatra_app, name: nil, version: nil, openapi_proc: nil, docs_proc: nil)
      @sinatra_app = sinatra_app
      @contracts = []
      @name = name
      @version = version
      @openapi_proc = openapi_proc
      @docs_proc = docs_proc
      @error_fallbacks = {}
      install_helpers
    end

    attr_reader :sinatra_app

    def get(path, request_class = nil, responses = {}, &block)
      define_route(:get, path, request_class, responses, &block)
    end

    def post(path, request_class = nil, responses = {}, &block)
      define_route(:post, path, request_class, responses, &block)
    end

    def put(path, request_class = nil, responses = {}, &block)
      define_route(:put, path, request_class, responses, &block)
    end

    def patch(path, request_class = nil, responses = {}, &block)
      define_route(:patch, path, request_class, responses, &block)
    end

    def delete(path, request_class = nil, responses = {}, &block)
      define_route(:delete, path, request_class, responses, &block)
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
      if @openapi_proc
        @openapi_proc.call
      else
        openapi_spec
      end
    end

    def docs_html
      if @docs_proc
        @docs_proc.call(swagger_path)
      else
        ::App::Api::OpenApi.ui_html(spec_url: swagger_path)
      end
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

    def install_helpers
      wrappers = if @sinatra_app.settings.respond_to?(:app_wrappers)
        @sinatra_app.settings.app_wrappers
      else
        nil
      end
      unless wrappers
        @sinatra_app.set :app_wrappers, []
        wrappers = @sinatra_app.settings.app_wrappers
      end

      wrappers << { prefix: route_prefix, wrapper: self }

      @sinatra_app.helpers do
        def app_wrapper
          wrappers = settings.app_wrappers || []
          path = request.path_info
          candidates = wrappers.select { |entry| entry[:prefix] && path.start_with?(entry[:prefix]) }
          selected = candidates.max_by { |entry| entry[:prefix].length }
          selected ||= wrappers.find { |entry| entry[:prefix].nil? } || wrappers.first
          selected ? selected[:wrapper] : nil
        end

        def swagger_spec
          app_wrapper&.swagger_spec
        end

        def docs_html
          app_wrapper&.docs_html
        end

        def normalize_payload(payload)
          wrapper = app_wrapper
          wrapper ? wrapper.normalize_payload(payload) : payload
        end

        def build_request(params_hash, payload)
          app_wrapper&.build_request(params_hash, payload)
        end

        def require_json_object(rack_request)
          app_wrapper&.require_json_object(rack_request)
        end

        def error_fallback_for(error)
          app_wrapper&.error_fallback_for(error)
        end
      end
    end

    def define_swagger_routes
      @sinatra_app.get(swagger_path) do
        spec = swagger_spec
        unless spec
          content_type :json
          status 500
          return JSON.generate({ error: "Swagger spec not configured" })
        end

        content_type :json
        JSON.generate(spec)
      end

      @sinatra_app.get(docs_path) do
        html = docs_html
        unless html
          content_type :json
          status 500
          return JSON.generate({ error: "Swagger UI not configured" })
        end

        content_type :html
        html
      end
    end

    def define_error_fallback(error_class, status: 500, response_class: ::App::Controllers::Shared::ErrorResponse)
      @error_fallbacks[error_class] = { status: status, response_class: response_class }
    end

    def error_fallback_for(error)
      @error_fallbacks.detect { |klass, _| error.is_a?(klass) }&.last
    end

    private

    def route_prefix
      return "/#{@version}" if @version
      return "/#{@name}" if @name
      nil
    end

    def openapi_spec(title: "Dynamic Entity API", version: "1.0.0")
      paths = {}
      schemas = {}

      @contracts.each do |contract|
        response_map = normalize_responses(contract[:responses] || {})
        @error_fallbacks.each_value do |fallback|
          response_map[fallback[:status]] ||= fallback[:response_class]
        end

        path = contract[:path].gsub(/:([a-zA-Z_]\w*)/, '{\1}')
        verb = contract[:verb].to_s
        paths[path] ||= {}

        route = {
          "summary" => "#{verb.upcase} #{path}",
          "responses" => {}
        }

        if contract[:request]
          request_schema = schema_for_class(contract[:request], schemas)
          if request_schema
            route["requestBody"] = {
              "required" => true,
              "content" => {
                "application/json" => {
                  "schema" => request_schema
                }
              }
            }
          end
        end

        response_map.each do |status, response_class|
          response_schema = schema_for_class(response_class, schemas)
          if response_schema
            route["responses"][status.to_s] = {
              "description" => status.to_s,
              "content" => {
                "application/json" => {
                  "schema" => response_schema
                }
              }
            }
          else
            route["responses"][status.to_s] = { "description" => status.to_s }
          end
        end

        paths[path][verb] = route
      end

      {
        "openapi" => "3.0.3",
        "info" => {
          "title" => title,
          "version" => version
        },
        "paths" => paths,
        "components" => {
          "schemas" => schemas
        }
      }
    end

    def schema_for_class(klass, schemas)
      return nil unless klass
      ::App::Api::OpenApi.schema_for_type(klass, schemas)
    end

    def normalize_responses(responses)
      responses.each_with_object({}) do |(status, klass), acc|
        if status.is_a?(Array)
          status.each { |entry| acc[entry] = klass }
        else
          acc[status] = klass
        end
      end
    end

    def define_route(verb, path, request_class, responses, &block)
      @contracts << {
        verb: verb,
        path: path,
        request: request_class,
        responses: responses
      }
      normalized_responses = normalize_responses(responses || {})

      @sinatra_app.send(verb, path) do
        response_status = 200
        response_body = nil

        begin
          request_payload = request_class ? require_json_object(request) : nil
          if request_class && request_class.respond_to?(:from_hash)
            request_payload = request_class.from_hash(request_payload)
          end

          request_obj = build_request(params, request_payload)

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

          if result.is_a?(::App::Controllers::Shared::Response)
            response_status = result.status
            response_body = result.body
          end

          if normalized_responses && !normalized_responses.empty?
            expected_class = normalized_responses[response_status]
            if expected_class.nil? || !response_body.is_a?(expected_class)
              raise ArgumentError, "Expected response to be #{expected_class&.name}, got #{response_body.class}"
            end
          end
        rescue StandardError => error
          fallback = error_fallback_for(error)
          if fallback
            response_status = fallback[:status]
            response_body = fallback[:response_class].new(error: error.message)
          else
            raise error
          end
        end

        content_type :json
        status response_status
        JSON.generate(normalize_payload(response_body))
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
      ::App::Controllers::Shared::Request.new(params: params_hash, json: request_payload)
    end

    public :require_json_object, :build_request, :normalize_payload
  end
end
