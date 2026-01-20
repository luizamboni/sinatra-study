# typed: true
# Tests can also be type-checked when Sorbet is enabled.

require "minitest/autorun"
require "sorbet-runtime"
require_relative "../app/app/start"
require_relative "../app/api/api"

ENV["RACK_ENV"] ||= "test"
