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
    # Given several attributes, like Rails' `pluck`, each method still runs
    # one query and returns a Hash keyed by attribute name in place of each
    # Amount: `{ quantity: ..., cost: ... }`, or per group
    # `{ "search" => { quantity: ..., cost: ... } }`. A group is in the result
    # when it has any row; an attribute with no amount in that group gets the
    # result of an empty set (zero for a fixed-symbol sum, else `nil`).
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
    #
    # @example Several attributes, one query
    #   UsageRecord.group(:kind).sum_amount(:quantity, :cost)
    #   # => { "search" => { quantity: #<Amount SEARCHES 3>, cost: #<Amount USDP $0.30> } }
    module Calculations
      # A fixed-symbol sum over no rows is zero; a multi-symbol one is `nil`.
      #
      # @param names [Array<Symbol, String>] one or more `has_amount` attributes
      # @return [Amount, Hash, nil] for several names, a Hash by name
      # @raise [Amount::TypeMismatch] when amounts of more than one symbol meet
      # @raise [ArgumentError] for no names, or a name given twice
      def sum_amount(*names)
        # SQL's SUM is NULL over no rows, and `none` runs no query at all;
        # Rails' `sum` is zero for both. `deserialize(0)` is that zero for a
        # fixed symbol and `nil` for a multi-symbol attribute.
        aggregate_amounts(names, :sum) { |definition, sum| sum || definition.type.deserialize(0) }
      end

      # @param names [Array<Symbol, String>] one or more `has_amount` attributes
      # @return [Amount, Hash, nil] `nil` over no rows; for several names, a Hash by name
      # @raise [Amount::TypeMismatch] when amounts of more than one symbol meet
      # @raise [ArgumentError] for no names, or a name given twice
      def minimum_amount(*names)
        aggregate_amounts(names, :minimum) { |_definition, minimum| minimum }
      end

      # @param names [Array<Symbol, String>] one or more `has_amount` attributes
      # @return [Amount, Hash, nil] `nil` over no rows; for several names, a Hash by name
      # @raise [Amount::TypeMismatch] when amounts of more than one symbol meet
      # @raise [ArgumentError] for no names, or a name given twice
      def maximum_amount(*names)
        aggregate_amounts(names, :maximum) { |_definition, maximum| maximum }
      end

      # The sum divided by the number of amounts, truncated toward zero to a
      # whole atomic unit, as `Amount#/` does. The sum and the count come from
      # the same query.
      #
      # @param names [Array<Symbol, String>] one or more `has_amount` attributes
      # @return [Amount, Hash, nil] `nil` over no rows; for several names, a Hash by name
      # @raise [Amount::TypeMismatch] when amounts of more than one symbol meet
      # @raise [ArgumentError] for no names, or a name given twice
      def average_amount(*names)
        aggregate_amounts(names, :sum, :count) { |_definition, sum, count| sum / count unless count.zero? }
      end

      private

      # Plucks `[*groups, *columns]`, where each attribute contributes its
      # symbol and one aggregate per operation, then folds each caller group's
      # rows per attribute. A multi-symbol attribute is grouped by its symbol
      # column too, so one caller group can span several rows.
      def aggregate_amounts(names, *operations, &fold)
        definitions = amount_definitions_for(names)
        groups = amount_group_values
        rows = amount_aggregate_scope(definitions)
               .pluck(*groups, *amount_aggregate_columns(definitions, operations))

        fold_rows = lambda do |group_rows|
          columns = group_rows.map { |row| row.drop(groups.size) }
          results = amount_fold_group(definitions, operations, columns, &fold)
          names.one? ? results.values.first : results
        end

        return fold_rows.call(rows) if groups.empty?

        rows.group_by { |row| amount_group_key(row.first(groups.size)) }.transform_values(&fold_rows)
      end

      def amount_definitions_for(names)
        raise ArgumentError, "pass at least one has_amount attribute" if names.empty?

        symbols = names.map(&:to_sym)
        repeated = symbols.detect { |symbol| symbols.count(symbol) > 1 }
        raise ArgumentError, "#{repeated} is given more than once" if repeated

        symbols.map { |symbol| amount_attribute_definitions.fetch(symbol) }
      end

      # The caller passed these to `group`, which takes raw SQL; `pluck` takes
      # a SQL string only wrapped in `Arel.sql`.
      def amount_group_values
        all.group_values.map do |group|
          reflection = group.respond_to?(:to_sym) && _reflect_on_association(group)
          if reflection
            raise ArgumentError,
                  "group by #{reflection.foreign_key}, not the #{group} association, to aggregate amounts"
          end

          group.is_a?(String) ? ::Arel.sql(group) : group
        end
      end

      # Each multi-symbol attribute is grouped by its symbol column, so each
      # row holds one symbol per attribute. A single multi-symbol attribute
      # also leaves out rows without an amount, so a group with no amount is
      # absent rather than `nil`; with several attributes a row may have one
      # amount and not another, and the fold skips each attribute's `NULL`s.
      def amount_aggregate_scope(definitions)
        multi_symbol = definitions.reject(&:fixed_symbol?)
        scope = all
        scope = scope.where.not(multi_symbol.first.symbol_column => nil) if definitions.one? && multi_symbol.one?

        multi_symbol.reduce(scope) { |grouped, definition| grouped.group(definition.symbol_column) }
      end

      # Per attribute: its symbol (a constant for a fixed symbol), then one
      # aggregate of its atomic column per operation.
      def amount_aggregate_columns(definitions, operations)
        definitions.flat_map do |definition|
          atomic = arel_table[definition.atomic_column]

          [amount_symbol_select(definition), *operations.map { |operation| atomic.public_send(operation) }]
        end
      end

      def amount_symbol_select(definition)
        return ::Arel::Nodes.build_quoted(definition.symbol.to_s) if definition.fixed_symbol?

        arel_table[definition.symbol_column]
      end

      def amount_group_key(values)
        values.size == 1 ? values.first : values
      end

      # One caller group's rows, folded per attribute, as `{ name => result }`.
      def amount_fold_group(definitions, operations, rows, &fold)
        width = operations.size + 1

        definitions.each_with_index.to_h do |definition, index|
          slices = rows.map { |row| row[index * width, width] }

          [definition.name, amount_fold(definition, operations, slices, &fold)]
        end
      end

      # One attribute's slices `[symbol, *aggregates]`, one per row: the rows
      # without its amount are skipped, the rest must share one symbol, and
      # each aggregate is combined across them before the fold sees it.
      def amount_fold(definition, operations, slices)
        present = slices.reject { |symbol, *| symbol.nil? }
        symbols = present.map(&:first).uniq
        if symbols.size > 1
          raise ::Amount::TypeMismatch, "#{definition.name} has more than one symbol in scope: #{symbols.join(', ')}"
        end

        atomic, *rest = operations.each_with_index.map do |operation, index|
          amount_combine(operation, present.map { |slice| slice[index + 1] })
        end

        yield(definition, definition.type.deserialize(atomic, symbols.first), *rest)
      end

      # Several rows' partial aggregates as one: sums and counts add up, and
      # the minimum or maximum is that of the partials. Over no rows, a count
      # is zero and everything else `nil`.
      def amount_combine(operation, values)
        values = values.compact
        return values.sum if operation == :count
        return if values.empty?

        case operation
        when :sum then values.sum
        when :minimum then values.min
        when :maximum then values.max
        end
      end
    end
  end
end
