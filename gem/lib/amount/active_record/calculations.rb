# frozen_string_literal: true

class Amount
  module ActiveRecord
    # Aggregates `has_amount` attributes in SQL and returns Amounts.
    #
    # Each method runs one query in the scope of the relation it is called
    # on, so `where` and `group` apply. Ungrouped, it returns one Amount (or
    # `nil`); grouped, it returns a Hash keyed like Rails' `group(...).sum`,
    # by the group's value, or by an array of values for several groups.
    # Group by a column or SQL expression; grouping by an association name
    # raises `ArgumentError` (group by its foreign key instead).
    #
    # Amounts of different symbols never combine: a multi-symbol attribute
    # with more than one symbol in scope, or in one group, raises
    # {Amount::TypeMismatch}. Group by its symbol column for one Amount per
    # symbol.
    #
    # @example
    #   UsageRecord.sum_amount(:cost)                    # => #<Amount USDP ...>
    #   UsageRecord.group(:kind).sum_amount(:cost)       # => { "search" => #<Amount USDP ...> }
    #   UsageRecord.group(:quantity_symbol).sum_amount(:quantity)
    module Calculations
      # A fixed-symbol sum over no rows is zero; a multi-symbol one is `nil`.
      #
      # @param name [Symbol, String] a `has_amount` attribute
      # @return [Amount, Hash, nil]
      # @raise [Amount::TypeMismatch] when amounts of more than one symbol meet
      def sum_amount(name)
        # SQL's SUM is NULL over no rows, and `none` runs no query at all;
        # Rails' `sum` is zero for both. `deserialize(0)` is that zero for a
        # fixed symbol and `nil` for a multi-symbol attribute.
        zero = amount_attribute_definitions.fetch(name.to_sym).type.deserialize(0)
        aggregate_amount(name, :sum) { |sum| sum || zero } || zero
      end

      # @param name [Symbol, String] a `has_amount` attribute
      # @return [Amount, Hash, nil] `nil` over no rows
      # @raise [Amount::TypeMismatch] when amounts of more than one symbol meet
      def minimum_amount(name)
        aggregate_amount(name, :minimum) { |minimum| minimum }
      end

      # @param name [Symbol, String] a `has_amount` attribute
      # @return [Amount, Hash, nil] `nil` over no rows
      # @raise [Amount::TypeMismatch] when amounts of more than one symbol meet
      def maximum_amount(name)
        aggregate_amount(name, :maximum) { |maximum| maximum }
      end

      # The sum divided by the number of amounts, truncated toward zero to a
      # whole atomic unit, as `Amount#/` does. The sum and the count come from
      # the same query.
      #
      # @param name [Symbol, String] a `has_amount` attribute
      # @return [Amount, Hash, nil] `nil` over no rows
      # @raise [Amount::TypeMismatch] when amounts of more than one symbol meet
      def average_amount(name)
        aggregate_amount(name, :sum, :count) { |sum, count| sum / count unless count.zero? }
      end

      private

      # Plucks the caller's groups, the symbol and the aggregates as
      # `[*groups, symbol, atomic, *rest]`, then yields each group's first
      # aggregate as an Amount, with the rest as they came.
      def aggregate_amount(name, *operations)
        definition = amount_attribute_definitions.fetch(name.to_sym)
        groups = amount_group_values
        atomic = arel_table[definition.atomic_column]

        rows = amount_aggregate_scope(definition)
               .pluck(*groups, amount_symbol_select(definition),
                      *operations.map { |operation| atomic.public_send(operation) })

        results = rows.group_by { |row| amount_group_key(row.first(groups.size)) }
                      .transform_values do |group_rows|
                        yield(*amount_group_values_of(definition, group_rows.map { |row| row.drop(groups.size) }))
                      end

        groups.empty? ? results[[]] : results
      end

      def amount_group_values
        all.group_values.each do |group|
          reflection = group.respond_to?(:to_sym) && _reflect_on_association(group)
          next unless reflection

          raise ArgumentError,
                "group by #{reflection.foreign_key}, not the #{group} association, to aggregate amounts"
        end
      end

      # A multi-symbol attribute is grouped by its symbol too, so each row is
      # one symbol's aggregate. Rows without an amount are left out.
      def amount_aggregate_scope(definition)
        return all if definition.fixed_symbol?

        where.not(definition.symbol_column => nil).group(definition.symbol_column)
      end

      def amount_symbol_select(definition)
        return ::Arel::Nodes.build_quoted(definition.symbol.to_s) if definition.fixed_symbol?

        arel_table[definition.symbol_column]
      end

      def amount_group_key(values)
        values.size == 1 ? values.first : values
      end

      def amount_group_values_of(definition, rows)
        unless rows.size == 1
          raise ::Amount::TypeMismatch,
                "#{definition.name} has more than one symbol in scope: #{rows.map(&:first).join(', ')}"
        end

        symbol, atomic, *rest = rows.first
        [definition.type.deserialize(atomic, symbol), *rest]
      end
    end
  end
end
