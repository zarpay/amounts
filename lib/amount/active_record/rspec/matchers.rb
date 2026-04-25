# frozen_string_literal: true

class Amount
  module ActiveRecord
    module RSpec
      # ActiveRecord-specific matcher definitions. Companion to
      # `Amount::RSpec::Matchers` which holds the gem-core matchers.
      module Matchers
        module_function

        def define_amount_column_matcher
          ::RSpec::Matchers.define :have_amount_column do |name, *expected_arguments|
            match do |record|
              @name = name
              @expected = Amount::RSpec::Support.coerce_amount_arguments(expected_arguments)
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
          ::RSpec::Matchers.define :match_amounts do |expected_hash|
            match do |actual_hash|
              @expected = expected_hash.to_h do |symbol, value|
                amount = Amount.new(value, symbol)
                [amount.symbol, amount]
              end
              @actual = Amount::RSpec::Support.normalize_amount_sums(actual_hash)

              @actual == @expected
            end

            failure_message do |_actual_hash|
              "expected grouped amounts #{@actual.inspect} to match #{@expected.inspect}"
            end
          end
        end
      end
    end
  end
end
