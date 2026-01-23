# typed: true

require "dry-struct"
require "dry-schema"
require_relative "../../app"
require_relative "../../types"
require_relative "field_payload"
require_relative "../../errors/validation_error"

module App::Controllers::Schemas
  class CreateSchemaRequest < Dry::Struct
    transform_keys(&:to_sym)

    attribute :name, App::Types::String
    attribute :fields, App::Types::Array.of(FieldPayload).constrained(min_size: 1)

    Schema = Dry::Schema.Params do
      required(:name).filled(:string)
      required(:fields).value(:array, min_size?: 1).each do
        hash do
          required(:name).filled(:string)
          required(:type).filled(:string)
        end
      end
    end

    def self.from_hash(payload)
      result = Schema.call(payload)
      unless result.success?
        raise App::Errors::ValidationError.new(
          "Invalid request payload",
          details: error_details(result.errors.to_h)
        )
      end
      new(result.to_h)
    end

    def self.error_details(errors)
      details = []

      errors.each do |key, value|
        if key == :fields && value.is_a?(Hash) && value.keys.all? { |entry| entry.is_a?(Integer) }
          value.each do |_index, entry|
            next unless entry.is_a?(Hash)
            entry.each do |field_key, field_errors|
              Array(field_errors).each do |message|
                details << "fields[].#{field_key} #{normalize_message(message)}"
              end
            end
          end
        elsif key == :fields && value.is_a?(Array)
          Array(value).each do |message|
            details << "fields #{normalize_message(message)}"
          end
        else
          Array(value).each do |message|
            details << "#{key} #{normalize_message(message)}"
          end
        end
      end

      details
    end

    def self.normalize_message(message)
      case message.to_s
      when "is missing", "must be filled"
        "is required"
      when /size must be >=/, /size cannot be less than/
        "is required"
      else
        "is invalid"
      end
    end
  end
end
