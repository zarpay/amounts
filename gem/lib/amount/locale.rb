# frozen_string_literal: true

class Amount
  # Internal: decides the effective locale and reads number formatting from
  # I18n. I18n is used only when it is already loaded; it is never required.
  module Locale
    DEFAULT_DELIMITER = ","
    DEFAULT_SEPARATOR = "."
    MISSING_I18N = "the i18n gem is required for locale-aware output; add it to your Gemfile and require it"

    module_function

    # @return [Boolean]
    def i18n_loaded?
      defined?(::I18n) ? true : false
    end

    # @raise [ArgumentError] when I18n isn't loaded
    def require_i18n!
      raise ArgumentError, MISSING_I18N unless i18n_loaded?
    end

    # 1. an explicit locale, 2. I18n.locale when Amount.localize, 3. nil.
    # @param explicit [Symbol, String, nil]
    # @return [Symbol, String, nil]
    def effective(explicit = nil)
      unless explicit.nil?
        require_i18n!
        return explicit
      end
      return nil unless Amount.localize?

      require_i18n!
      ::I18n.locale
    end

    # @return [Hash{Symbol=>String}] `:delimiter` and `:separator`
    def number_format(locale)
      format = ::I18n.t("number.format", locale:, default: {})
      format = {} unless format.is_a?(Hash)
      {
        delimiter: format[:delimiter] || DEFAULT_DELIMITER,
        separator: format[:separator] || DEFAULT_SEPARATOR
      }
    end

    # Picks a form from a plural hash without I18n: `:one` when the number
    # equals 1, else `:other`. Strings pass through.
    # @param label [String, Hash, nil]
    # @param count [BigDecimal, nil]
    def plain(label, count)
      return label unless label.is_a?(Hash)

      count == 1 && label.key?(:one) ? label[:one] : label[:other]
    end

    # Label of a registered type: its `label_key`, then
    # `amounts.units.<symbol downcased>`, then `display_symbol`.
    # @return [String, nil]
    def type_label(entry, locale, count = nil)
      key = entry.label_key || "amounts.units.#{entry.symbol.to_s.downcase}"
      translate(key, locale, entry.display_symbol, count)
    end

    # Label of a display unit: the spec's `label_key`, then
    # `amounts.display_units.<symbol downcased>.<unit>`, then the spec's
    # `:symbol`, then the type's label.
    # @return [String, nil]
    def unit_label(entry, unit, spec, locale, count = nil)
      key = spec[:label_key] || "amounts.display_units.#{entry.symbol.to_s.downcase}.#{unit}"
      translate(key, locale, spec[:symbol] || type_label(entry, locale, count), count)
    end

    # Looks a key up, falling back to `default` so a miss never yields
    # "translation missing". With a count, I18n pluralizes a hash translation
    # or default using the locale's rules; without one, or when the form is
    # missing, the `:other` form is used.
    def translate(key, locale, default, count = nil)
      opts = count.nil? ? {} : { count: whole(count) }
      found = ::I18n.t(key.to_s, locale:, default:, **opts)
      found.is_a?(Hash) ? found[:other] : found
    rescue ::I18n::InvalidPluralizationData => e
      e.entry[:other]
    end

    # 1.0 -> 1, so custom pluralization rules can match integers.
    def whole(count)
      count.frac.zero? ? count.to_i : count
    end

    # Rewrites a plain "-1234.50" style number with the locale's characters.
    # @param str [String] output of `format("%.Nf", value)`
    # @return [String]
    def apply(str, locale)
      fmt = number_format(locale)
      sign = str.start_with?("-") ? "-" : ""
      int, frac = str.delete_prefix("-").split(".", 2)
      int = int.reverse.scan(/\d{1,3}/).join(fmt[:delimiter].reverse).reverse
      "#{sign}#{int}#{frac ? "#{fmt[:separator]}#{frac}" : ''}"
    end
  end
end
