# frozen_string_literal: true

class Amount
  module ActiveRecord
    # Adds `t.amount` to migrations.
    #
    # Multi-symbol amounts create `*_atomic` and `*_symbol` columns. Fixed
    # symbol amounts create only the atomic column.
    #
    # @example
    #   create_table :holdings do |t|
    #     t.amount :amount
    #     t.amount :fee, symbol: :SOL
    #     t.amount :reserve, precision: 40
    #   end
    module MigrationMethods
      # Adds one amount attribute to the table definition.
      #
      # @param name [Symbol, String] logical attribute name
      # @param precision [Integer] numeric precision for the atomic column
      # @param symbol [Symbol, nil] fixed symbol for a single-column amount
      # @param options [Hash] standard column options applied to the generated columns
      # @return [void]
      def amount(name, precision: 78, symbol: nil, **options)
        default = options.delete(:default)
        null = options.key?(:null) ? options[:null] : nil
        comment = options[:comment]

        defaults = normalize_defaults(default, symbol)

        decimal_options = {
          precision:,
          scale: 0,
          default: defaults[:atomic],
          comment:
        }
        decimal_options[:null] = null unless null.nil?
        decimal(name_to_atomic(name), **decimal_options.compact)

        return if symbol

        string_options = {
          limit: 10,
          default: defaults[:symbol],
          comment:
        }
        string_options[:null] = null unless null.nil?
        string(name_to_symbol(name), **string_options.compact)
      end

      private

      def normalize_defaults(default, symbol)
        return {} if default.nil?

        type = Type.new(symbol:)
        amount = type.cast(default)

        {
          atomic: amount.atomic.to_s,
          symbol: symbol ? nil : amount.symbol.to_s
        }
      end

      def name_to_atomic(name)
        :"#{name}_atomic"
      end

      def name_to_symbol(name)
        :"#{name}_symbol"
      end
    end
  end
end
