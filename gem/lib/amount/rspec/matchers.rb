# frozen_string_literal: true

class Amount
  module RSpec
    # Internal matcher helpers for the opt-in RSpec integration.
    #
    # All bare `RSpec` references inside this module are fully qualified to
    # `::RSpec` to dodge the constant-lookup ambiguity introduced by living
    # under `Amount::RSpec`.
    module Matchers
      module_function

      def define_amount_equality_matcher(name, &expected_builder)
        ::RSpec::Matchers.define name do |*arguments|
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
        ::RSpec::Matchers.define name do
          match do |actual|
            actual.is_a?(Amount) && instance_exec(actual, &predicate)
          end

          failure_message do |actual|
            "expected #{actual.inspect} to be #{description}"
          end
        end
      end

      def define_amount_type_matcher
        ::RSpec::Matchers.define :be_amount_of do |expected_symbol|
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
        ::RSpec::Matchers.define :be_approximately_amount do |*expected_arguments, within:|
          match do |actual|
            @expected = Amount::RSpec::Support.coerce_amount_arguments(expected_arguments)
            @within = Amount::RSpec::Support.coerce_delta(@expected, within)

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
    end
  end
end
