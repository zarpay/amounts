# frozen_string_literal: true

class Amount
  # Concern: the shared type registry and the class-level shortcuts for
  # registering types and default rates.
  #
  # The registry lives on `Amount` itself, never on a subclass, so
  # `GoldAmount.registry` and `Amount.registry` are the same object. Swapping
  # it removes the outgoing registry's generated constructors (`of_usdc`) and
  # installs the incoming one's.
  module Registrable
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level methods extended onto any class that does
    # `include Registrable`.
    module ClassMethods
      # @return [Amount::Registry]
      # @example Accessing the shared registry
      #   Amount.registry.locked?
      #   # => false
      def registry
        Amount.instance_variable_get(:@registry) ||
          replace_registry(Registry.new)
      end

      # @param symbol [Symbol, String]
      # @param opts [Hash]
      # @return [void]
      # @example Registering a type
      #   Amount.register :USDC,
      #     decimals: 6,
      #     display_symbol: "$",
      #     display_position: :prefix,
      #     ui_decimals: 2
      def register(symbol, **opts)
        registry.register(symbol, **opts)
      end

      # @param from [Symbol, String]
      # @param to [Symbol, String]
      # @param rate [String, Numeric, BigDecimal]
      # @return [void]
      # @example Registering a directional default rate
      #   Amount.register_default_rate :USD, :USDC, "1"
      def register_default_rate(from, to, rate)
        registry.register_default_rate(from, to, rate)
      end

      # Temporarily swaps the global registry. Intended for tests.
      #
      # @param registry [Amount::Registry]
      # @yield
      # @return [Object]
      # @example Using a temporary registry
      #   test_registry = Amount::Registry.new
      #   Amount.with_registry(test_registry) do
      #     Amount.register :TEST, decimals: 2
      #   end
      def with_registry(registry)
        original = Amount.instance_variable_get(:@registry)
        replace_registry(registry)
        yield
      ensure
        replace_registry(original)
      end

      private

      def replace_registry(registry)
        current = Amount.instance_variable_get(:@registry)
        current&.remove_generated_methods!
        Amount.instance_variable_set(:@registry, registry)
        registry&.activate_generated_methods!
        registry
      end
    end
  end
end
