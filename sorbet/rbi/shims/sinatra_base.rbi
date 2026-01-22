# typed: true

module Sinatra
  class Base
    sig { params(key: Symbol, value: T.untyped).void }
    def self.set(key, value); end

    sig { returns(T.untyped) }
    def settings; end

    sig { returns(T.untyped) }
    def request; end

    sig { returns(T.untyped) }
    def params; end

    sig { params(_type: T.untyped).void }
    def content_type(_type); end

    sig { params(_status: Integer).void }
    def status(_status); end
  end
end
