# typed: false

require_relative "../errors/validation_error"

module App::Api
  module ErrorSanitizer
    def self.sanitize(error)
      if error.is_a?(App::Errors::ValidationError)
        details = error.details
        return details.empty? ? [error.message] : details
      end

      if defined?(Dry::Struct::Error) && error.is_a?(Dry::Struct::Error)
        sanitize_dry_struct_error(error.message)
      else
        [error.message]
      end
    end

    def self.sanitize_dry_struct_error(message)
      details = []

      if message.include?("FieldPayload")
        details << "fields[].name is required" if message.match?(/:name is missing/)
        details << "fields[].type is required" if message.match?(/:type is missing/)
      end

      has_attribute_payload = message.include?("AttributePayload")
      if has_attribute_payload
        details << "attributes[].name is required" if message.match?(/:name is missing/)
        details << "attributes[].value is required" if message.match?(/:value is missing/)
      end

      if message.include?("CreateSchemaRequest") && !message.include?("FieldPayload")
        details << "name is required" if message.match?(/:name is missing/)
        details << "fields is invalid" if message.match?(/invalid type for :fields/)
      end

      if message.include?("CreateEntityRequest") && !has_attribute_payload
        details << "attributes is invalid" if message.match?(/invalid type for :attributes/)
      end

      return details.map(&:strip).uniq unless details.empty?

      message.scan(/invalid type for :([a-zA-Z0-9_]+)/).each do |match|
        details << "#{match.first} is invalid"
      end

      message.scan(/:([a-zA-Z0-9_]+) is missing/).each do |match|
        details << "#{match.first} is required"
      end

      details.map(&:strip).uniq
    end
  end
end
