# typed: true

require "dry-struct"
require "dry-schema"
require_relative "../../app"
require_relative "../../types"
require_relative "attribute_payload"
require_relative "../../errors/validation_error"

module App::Controllers::Entities
  class CreateEntityRequest < Dry::Struct
    transform_keys(&:to_sym)

    attribute :attributes, App::Types::Array.of(AttributePayload).constrained(min_size: 1)

    alias_method :attributes_hash, :attributes

    def attributes
      self[:attributes]
    end

    Schema = Dry::Schema.Params do
      required(:attributes).value(:array, min_size?: 1).each do
        hash do
          required(:name).filled(:string)
          required(:value).filled
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
        if key == :attributes && value.is_a?(Hash) && value.keys.all? { |entry| entry.is_a?(Integer) }
          value.each do |_index, entry|
            next unless entry.is_a?(Hash)
            entry.each do |attr_key, attr_errors|
              Array(attr_errors).each do |message|
                details << "attributes[].#{attr_key} #{normalize_message(message)}"
              end
            end
          end
        elsif key == :attributes && value.is_a?(Array)
          Array(value).each do |message|
            details << "attributes #{normalize_message(message)}"
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
