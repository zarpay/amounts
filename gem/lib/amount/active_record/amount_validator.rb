# frozen_string_literal: true

class Amount
  module ActiveRecord
    # Validates model-level business rules for `has_amount` attributes.
    #
    # Structural integrity is still handled by `has_amount` itself. This
    # validator adds declarative Rails validations such as symbol checks and
    # comparison constraints.
    #
    # @example Requiring a specific symbol
    #   class Holding < ApplicationRecord
    #     has_amount :amount
    #     validates :amount, amount: { symbol: :USDC }
    #   end
    #
    # @example Applying numeric thresholds to a fixed-symbol amount
    #   class FeeSchedule < ApplicationRecord
    #     has_amount :fee, symbol: :SOL
    #     validates :fee, amount: { greater_than_or_equal_to: 0 }
    #   end
    class AmountValidator < ::ActiveModel::EachValidator
      COMPARATORS = {
        greater_than: :>,
        greater_than_or_equal_to: :>=,
        less_than: :<,
        less_than_or_equal_to: :<=
      }.freeze

      def validate_each(record, attribute, value)
        return if pending_assignment_error?(record, attribute)
        return if value.nil?

        validate_amount_instance(record, attribute, value)
        validate_symbol(record, attribute, value)
        validate_comparators(record, attribute, value)
      end

      private

      def validate_amount_instance(record, attribute, value)
        return if value.is_a?(::Amount)

        record.errors.add(attribute, :amount_type)
      end

      def validate_symbol(record, attribute, value)
        expected_symbol = options[:symbol]&.to_sym
        return unless expected_symbol
        return if value.symbol == expected_symbol

        record.errors.add(attribute, :amount_symbol, expected: expected_symbol)
      end

      def validate_comparators(record, attribute, value)
        COMPARATORS.each do |option_name, operator|
          next unless options.key?(option_name)

          other = coerce_comparison_amount(record, attribute, options.fetch(option_name), value)
          next unless other

          compare_amounts(record, attribute, value, operator, other, option_name)
        rescue ::Amount::Error, ArgumentError => error
          record.errors.add(attribute, :amount_invalid_constraint, option: option_name, message: error.message)
        end
      end

      def coerce_comparison_amount(record, attribute, candidate, value)
        return candidate if candidate.is_a?(::Amount)

        definition = fetch_definition(record, attribute)
        return definition.type.cast(candidate) if definition.type.fixed_symbol
        return ::Amount.new(candidate, value.symbol, from: :float) if candidate.is_a?(Numeric)

        definition.type.cast(candidate)
      end

      def compare_amounts(record, attribute, value, operator, other, option_name)
        comparison = value <=> other
        if comparison.nil?
          record.errors.add(attribute, :amount_incomparable,
                            symbol: value.symbol, other_symbol: other.symbol, option: option_name)
          return
        end

        return if comparison.public_send(operator, 0)

        record.errors.add(attribute, failure_key(option_name), count: other.to_s)
      end

      # Rails' own keys, so apps that translate them get these for free.
      def failure_key(option_name)
        COMPARATORS.key?(option_name) ? option_name : :invalid
      end

      def fetch_definition(record, attribute)
        record.class.amount_attribute_definitions.fetch(attribute.to_sym)
      rescue KeyError
        raise ArgumentError, "#{record.class.name}##{attribute} is not declared with has_amount"
      end

      def pending_assignment_error?(record, attribute)
        record.send(:pending_amount_assignment_errors).key?(attribute.to_sym)
      end
    end
  end
end

::AmountValidator = Amount::ActiveRecord::AmountValidator unless defined?(::AmountValidator)
