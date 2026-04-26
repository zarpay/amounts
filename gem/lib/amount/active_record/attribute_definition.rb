# frozen_string_literal: true

class Amount
  module ActiveRecord
    # Describes one `has_amount` attribute and its backing columns.
    class AttributeDefinition
      attr_reader :name, :type, :symbol

      def initialize(name, symbol: nil)
        @name = name.to_sym
        @symbol = symbol&.to_sym
        @type = Type.new(symbol: @symbol)
      end

      def fixed_symbol?
        !@symbol.nil?
      end

      def atomic_column
        "#{name}_atomic"
      end

      def symbol_column
        "#{name}_symbol"
      end

      def component_columns
        columns = [atomic_column]
        columns << symbol_column unless fixed_symbol?
        columns
      end

      def read(record)
        type.deserialize(record.read_attribute(atomic_column), resolved_symbol(record))
      end

      def write(record, value)
        if value.nil?
          record.write_attribute(atomic_column, nil)
          record.write_attribute(symbol_column, nil) unless fixed_symbol?
          return nil
        end

        record.write_attribute(atomic_column, value.atomic.to_s)
        record.write_attribute(symbol_column, value.symbol.to_s) unless fixed_symbol?
        value
      end

      def build_from_values(values)
        type.deserialize(values[atomic_column], fixed_symbol? ? symbol : values[symbol_column])
      end

      def query_relation(model, value)
        amount = type.cast(value)
        relation_for_symbol(model, amount).where(atomic_column => amount.atomic)
      end

      def greater_than_relation(model, value)
        query_relation_with_operator(model, value, :>)
      end

      def greater_than_or_equal_relation(model, value)
        query_relation_with_operator(model, value, :>=)
      end

      def less_than_relation(model, value)
        query_relation_with_operator(model, value, :<)
      end

      def less_than_or_equal_relation(model, value)
        query_relation_with_operator(model, value, :<=)
      end

      def between_relation(model, lower, upper)
        lower_amount = type.cast(lower)
        upper_amount = type.cast(upper)
        ensure_same_query_symbol!(lower_amount, upper_amount)

        relation_for_symbol(model, lower_amount)
          .where("#{atomic_column} >= ? AND #{atomic_column} <= ?", lower_amount.atomic, upper_amount.atomic)
      end

      def currency_relation(model, symbol)
        model.where(symbol_column => symbol.to_s)
      end

      def changed?(record)
        component_columns.any? { |column| record.will_save_change_to_attribute?(column) }
      end

      def change(record)
        return unless changed?(record)

        [value_in_database(record), read(record)]
      end

      def value_in_database(record)
        values = component_columns.to_h do |column|
          [column, record.attribute_in_database(column)]
        end

        build_from_values(values)
      end

      def saved_change?(record)
        component_columns.any? { |column| record.saved_change_to_attribute?(column) }
      end

      def saved_change(record)
        return unless saved_change?(record)

        [
          build_from_values(previous_values(record, before: true)),
          build_from_values(previous_values(record, before: false))
        ]
      end

      def before_last_save(record)
        saved_change(record)&.first
      end

      def validate(record)
        add_assignment_error(record)

        atomic = record.read_attribute(atomic_column)
        return if atomic.nil? && fixed_symbol?

        if fixed_symbol?
          validate_deserialization(record, atomic, symbol)
          return
        end

        symbol_value = record.read_attribute(symbol_column)
        if atomic.nil? != symbol_value.nil?
          record.errors.add(name, "must set both atomic and symbol or neither")
          return
        end

        return if atomic.nil? && symbol_value.nil?

        validate_deserialization(record, atomic, symbol_value)
      end

      private

      def resolved_symbol(record)
        fixed_symbol? ? symbol : record.read_attribute(symbol_column)
      end

      def query_relation_with_operator(model, value, operator)
        amount = type.cast(value)
        relation_for_symbol(model, amount)
          .where("#{atomic_column} #{operator} ?", amount.atomic)
      end

      def relation_for_symbol(model, amount)
        return model if fixed_symbol?

        model.where(symbol_column => amount.symbol.to_s)
      end

      def ensure_same_query_symbol!(left, right)
        return if left.symbol == right.symbol

        raise ::Amount::TypeMismatch, "query bounds must use the same symbol: #{left.symbol} vs #{right.symbol}"
      end

      def previous_values(record, before:)
        component_columns.to_h do |column|
          change = record.saved_change_to_attribute(column)
          value = if change
                    change.public_send(before ? :first : :last)
                  else
                    record.read_attribute(column)
                  end
          [column, value]
        end
      end

      def add_assignment_error(record)
        message = record.send(:pending_amount_assignment_errors)[name]
        record.errors.add(name, message) if message
      end

      def validate_deserialization(record, atomic, currency_value)
        type.deserialize(atomic, currency_value)
      rescue ::Amount::Error => error
        record.errors.add(name, error.message)
      end
    end
  end
end
