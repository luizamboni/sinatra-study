# typed: true

module T
  module Private
    module Methods
      class Signature
        sig { returns(T::Hash[Symbol, T.untyped]) }
        def kwarg_types; end

        sig { returns(T.untyped) }
        def return_type; end
      end
    end
  end
end
