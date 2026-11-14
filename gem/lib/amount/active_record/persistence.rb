# frozen_string_literal: true

class Amount
  module ActiveRecord
    # Prepares `has_amount` attributes for Rails' bulk writes (`insert_all`,
    # `upsert_all` and their variants), which skip attribute writers and take
    # column values only.
    module Persistence
      # Turns attributes, with amounts by name, into column values. Each
      # amount is cast as its writer would cast it and replaced by its
      # component columns, all of them even for `nil`, so rows share keys.
      # Any other key passes through.
      #
      # @param attributes [Hash] attributes keyed by String or Symbol
      # @return [Hash]
      # @raise [Amount::TypeMismatch] when a fixed-symbol amount has another
      #   symbol (the writer records this as a validation error instead;
      #   `insert_all` doesn't validate)
      # @example
      #   UsageRecord.amount_column_values("cost" => "USDP|0.0042", "kind" => "model_call")
      #   # => { "cost_atomic" => 42000000, "kind" => "model_call" }
      #
      #   UsageRecord.insert_all(rows.map { |row| UsageRecord.amount_column_values(row) })
      def amount_column_values(attributes)
        attributes.each_with_object({}) do |(key, value), columns|
          definition = amount_attribute_definitions[key.to_sym]
          next columns[key] = value unless definition

          columns.merge!(definition.column_values(definition.type.cast(value)))
        end
      end
    end
  end
end
