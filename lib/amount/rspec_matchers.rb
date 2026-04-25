# frozen_string_literal: true

class Amount
  # Internal matcher helpers for the opt-in RSpec integration.
  module RSpecMatchers
    module_function

    def define_amount_equality_matcher(name, &expected_builder)
      RSpec::Matchers.define name do |*arguments|
        match do |actual|
          @expected = instance_exec(*arguments, &expected_builder)
          actual.is_a?(Amount) && actual == @expected
        end

        failure_message do |actual|
          return "expected #{actual.inspect} to be an Amount equal to #{@expected.inspect}" unless actual.is_a?(Amount)

          "expected #{actual.inspect} to equal amount #{@expected.inspect}"
        end
      end
    end

    def define_amount_predicate_matcher(name, description, &predicate)
      RSpec::Matchers.define name do
        match do |actual|
          actual.is_a?(Amount) && instance_exec(actual, &predicate)
        end

        failure_message do |actual|
          "expected #{actual.inspect} to be #{description}"
        end
      end
    end

    def define_amount_type_matcher
      RSpec::Matchers.define :be_amount_of do |expected_symbol|
        match do |actual|
          @expected_symbol = expected_symbol.to_sym
          actual.is_a?(Amount) && actual.symbol == @expected_symbol
        end

        failure_message do |actual|
          "expected #{actual.inspect} to be an Amount of #{@expected_symbol}"
        end
      end
    end

    def define_approximate_amount_matcher
      RSpec::Matchers.define :be_approximately_amount do |*expected_arguments, within:|
        match do |actual|
          @expected = Amount::RSpecSupport.coerce_amount_arguments(expected_arguments)
          @within = Amount::RSpecSupport.coerce_delta(@expected, within)

          actual.is_a?(Amount) &&
            actual.same_type?(@expected) &&
            @within.same_type?(@expected) &&
            (actual - @expected).abs.atomic <= @within.atomic
        end

        failure_message do |actual|
          return "expected #{actual.inspect} to be an Amount within #{@within.inspect} of #{@expected.inspect}" unless actual.is_a?(Amount)

          "expected #{actual.inspect} to be within #{@within.inspect} of #{@expected.inspect}"
        end
      end
    end

    def define_amount_column_matcher
      RSpec::Matchers.define :have_amount_column do |name, *expected_arguments|
        match do |record|
          @name = name
          @expected = Amount::RSpecSupport.coerce_amount_arguments(expected_arguments)
          @definition = record.class.amount_attribute_definitions.fetch(name.to_sym)

          @definition.read(record) == @expected &&
            record.public_send(@definition.atomic_column).to_i == @expected.atomic &&
            (@definition.fixed_symbol? ||
              record.public_send(@definition.symbol_column) == @expected.symbol.to_s)
        end

        failure_message do |record|
          "expected #{record.inspect} to have #{@name} column matching #{@expected.inspect}"
        end
      end
    end

    def define_amount_sum_matcher
      RSpec::Matchers.define :match_amounts do |expected_hash|
        match do |actual_hash|
          @expected = expected_hash.to_h do |symbol, value|
            amount = Amount.new(value, symbol)
            [amount.symbol, amount]
          end
          @actual = Amount::RSpecSupport.normalize_amount_sums(actual_hash)

          @actual == @expected
        end

        failure_message do |_actual_hash|
          "expected grouped amounts #{@actual.inspect} to match #{@expected.inspect}"
        end
      end
    end
  end
end
