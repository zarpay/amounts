# frozen_string_literal: true

class Amount
  module ActiveRecord
    # Change hashes with each `has_amount` attribute by its name, as
    # `[before, after]` Amounts, in place of its component columns.
    # `has_amount` includes it into the model that declares an amount.
    #
    # Rails' own `changes` and `saved_changes` are left as they are, keyed
    # by column, for the code and gems that read them that way.
    #
    # @example
    #   subscription.update!(owed: Amount.of_usd("10.06"))
    #   subscription.saved_changes        # => { "owed_atomic" => [0, 1006], ... }
    #   subscription.saved_amount_changes # => { "owed" => [#<Amount USD $0.00>, #<Amount USD $10.06>], ... }
    module Dirty
      # Like `changes`: the changes not yet saved.
      #
      # @return [ActiveSupport::HashWithIndifferentAccess]
      def amount_changes
        amounts_in_place_of_column_changes(changes) { |definition| definition.change(self) }
      end

      # Like `saved_changes`: the changes the last save made.
      #
      # @return [ActiveSupport::HashWithIndifferentAccess]
      def saved_amount_changes
        amounts_in_place_of_column_changes(saved_changes) { |definition| definition.saved_change(self) }
      end

      private

      def amounts_in_place_of_column_changes(column_changes)
        self.class.amount_attribute_definitions.each_value do |definition|
          change = yield(definition)
          definition.component_columns.each { |column| column_changes.delete(column) }
          column_changes[definition.name.to_s] = change if change
        end
        column_changes
      end
    end
  end
end
