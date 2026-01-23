# typed: true

require "sorbet-runtime"
require_relative "../app"

module App::Errors
  class ValidationError < StandardError
    extend T::Sig

    sig { returns(T::Array[String]) }
    attr_reader :details

    sig { params(message: String, details: T::Array[String]).void }
    def initialize(message = "Invalid request payload", details: [])
      super(message)
      @details = details
    end
  end
end
