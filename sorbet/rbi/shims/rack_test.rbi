# typed: true

module Rack
  module Test
    module Methods
      sig { params(uri: T.any(String, Regexp), params: T.untyped, env: T.untyped).void }
      def get(uri, params = nil, env = nil); end

      sig { params(uri: T.any(String, Regexp), params: T.untyped, env: T.untyped).void }
      def post(uri, params = nil, env = nil); end

      sig { returns(T.untyped) }
      def last_response; end
    end
  end
end
