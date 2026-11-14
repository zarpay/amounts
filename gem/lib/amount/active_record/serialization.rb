# frozen_string_literal: true

class Amount
  module ActiveRecord
    # Writes each `has_amount` attribute by its name, as the amount, in place
    # of its component columns: `as_json` gives `"owed" => "USD|10.06"`
    # rather than `"owed_atomic" => 1006`. `has_amount` includes it into the
    # model that declares an amount.
    #
    # `only:` and `except:` take the amount's name. `amounts: false` writes
    # the component columns instead, for one call. An amount whose columns
    # weren't all selected keeps the columns that were.
    #
    # @example
    #   subscription.as_json                  # => { "id" => 1, "owed" => "USD|10.06" }
    #   subscription.as_json(only: :owed)     # => { "owed" => "USD|10.06" }
    #   subscription.as_json(amounts: false)  # => { "id" => 1, "owed_atomic" => 1006 }
    module Serialization
      # @param options [Hash, nil] Rails' options, plus `amounts: false`
      # @return [Hash]
      def serializable_hash(options = nil)
        options = options ? options.dup : {}
        return super(options) if options.delete(:amounts) == false

        definitions = self.class.amount_attribute_definitions.values
        amounts_in_place_of_columns(super(amount_names_as_columns(options, definitions)), definitions)
      end

      private

      # Rails filters `only:` and `except:` by column, so an amount's name
      # becomes its component columns.
      def amount_names_as_columns(options, definitions)
        columns = definitions.to_h { |definition| [definition.name.to_s, definition.component_columns] }

        %i[only except].each do |key|
          next unless options.key?(key)

          options[key] = Array(options[key]).flat_map { |name| columns.fetch(name.to_s) { name.to_s } }
        end
        options
      end

      # Each amount takes its atomic column's place; its symbol column drops out.
      def amounts_in_place_of_columns(hash, definitions)
        serialized = definitions.select { |definition| (definition.component_columns - hash.keys).empty? }
        by_atomic_column = serialized.to_h { |definition| [definition.atomic_column, definition] }
        symbol_columns = serialized.reject(&:fixed_symbol?).map(&:symbol_column)

        hash.each_with_object({}) do |(key, value), result|
          definition = by_atomic_column[key]
          next result[definition.name.to_s] = public_send(definition.name) if definition

          result[key] = value unless symbol_columns.include?(key)
        end
      end
    end
  end
end
