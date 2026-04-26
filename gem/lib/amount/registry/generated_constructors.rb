# frozen_string_literal: true

class Amount
  class Registry
    # Manages registry-driven constructor methods such as `Amount.usdc(...)`.
    class GeneratedConstructors
      METHOD_NAME_PATTERN = /\A[a-z_][a-z0-9_]*\z/

      def initialize(target: Amount)
        @target = target
        @method_names = []
      end

      def define_for(entry)
        method_name = method_name_for(entry.symbol)
        return unless method_name

        raise_collision!(method_name)

        @target.define_singleton_method(method_name) do |value, **opts|
          resolved_entry = registry.lookup(entry.symbol)
          resolved_entry.amount_class.new(value, entry.symbol, **opts)
        end

        @method_names << method_name.to_sym
      end

      def activate(entries)
        entries.each_value { |entry| define_for(entry) }
      end

      def remove_all
        @method_names.each do |method_name|
          remove_method(method_name)
        end

        @method_names.clear
      end

      private

      def method_name_for(symbol)
        method_name = symbol.to_s.downcase
        return unless method_name.match?(METHOD_NAME_PATTERN)

        method_name
      end

      def raise_collision!(method_name)
        return unless @target.respond_to?(method_name)

        raise AlreadyRegistered, "cannot generate #{@target}.#{method_name} - method already exists"
      end

      def remove_method(method_name)
        return unless @target.singleton_class.method_defined?(method_name)

        @target.singleton_class.send(:remove_method, method_name)
      end
    end
  end
end
