# frozen_string_literal: true

class Amount
  # Concern: the global switch that makes output and input follow
  # `I18n.locale` when no `locale:` is given.
  #
  # Every locale-aware method (`ui`, `unit_label`, `display_format`,
  # `Amount.parse_ui`) resolves its locale through {Locale.effective}, which
  # reads this switch.
  #
  # @example
  #   Amount.localize = true
  #   I18n.locale = :de
  #   Amount.of_usd("1500.5").ui # formatted with de's number.format
  module Localizable
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level methods extended onto any class that does
    # `include Localizable`.
    module ClassMethods
      # Whether `ui` formats numbers for `I18n.locale` when no `locale:` is
      # given. Defaults to `false`.
      # @return [Boolean]
      def localize?
        @localize ? true : false
      end
      alias localize localize?

      # @param value [Boolean]
      # @raise [ArgumentError] when enabling without I18n loaded
      def localize=(value)
        Locale.require_i18n! if value
        @localize = value ? true : false
      end
    end
  end
end
