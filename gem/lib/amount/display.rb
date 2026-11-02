# frozen_string_literal: true

require "bigdecimal"

class Amount
  # Formats amounts for UI output without changing their type.
  class Display
    # @param amount [Amount]
    def initialize(amount)
      @amount = amount
      @entry = amount.registry_entry
    end

    # @return [String]
    def formatted
      format("%.#{@entry.decimals}f", @amount.decimal)
    end

    # @param unit [Symbol, nil]
    # @param direction [Symbol]
    # @param decorated [Boolean] when `false`, omit the display symbol and
    #   return just the rounded number. Useful when the caller renders the
    #   currency label separately (e.g. in a column header or a chip).
    # @param trim_zeros [Boolean, nil] strip trailing zeros from the formatted
    #   number. When `nil` (the default), falls back to the display unit's
    #   setting, then the registry entry's setting. An explicit `true` or
    #   `false` overrides both.
    # @param locale [Symbol, String, nil] format the number with this locale's
    #   `number.format` delimiter and separator (requires I18n). When `nil`,
    #   uses `I18n.locale` if `Amount.localize` is true, else plain output.
    # @return [String]
    # @example
    #   Amount.of_usdc("1.50").ui                       # => "$1.50"
    #   Amount.of_usdc("1.50").ui(decorated: false)     # => "1.50"
    #   Amount.of_gold("1").ui(unit: :gram)             # => "31.10 g"
    #   Amount.of_gold("1").ui(unit: :gram, decorated: false)  # => "31.10"
    #   Amount.of_sol("2.5").ui(trim_zeros: true)       # => "2.5 SOL"
    #   # EUR registered with display_format: "%u%n"; de.yml has
    #   # amounts.formats.eur: "%n\u00A0%u"
    #   Amount.of_eur("12.5").ui(locale: :en)           # => "€12.50"
    #   Amount.of_eur("12.5").ui(locale: :de)           # => "12,50\u00A0€"
    def ui(unit: nil, direction: :floor, decorated: true, trim_zeros: nil, locale: nil)
      locale = Locale.effective(locale)
      if unit
        render_display_unit(unit, direction, decorated:, trim_zeros:, locale:)
      else
        render_default(direction, decorated:, trim_zeros:, locale:)
      end
    end

    # The unit label alone, for column headers and chips that render it
    # separately. Follows the same rules as `ui`: translated through I18n only
    # when a locale is given or `Amount.localize` is true, else `display_symbol`
    # (or the display unit's `:symbol`).
    # @param unit [Symbol, nil] display unit
    # @param locale [Symbol, String, nil]
    # @return [String]
    # @example
    #   Amount.of_searches(3).unit_label(locale: :de)  # => "Suchen"
    def unit_label(unit: nil, locale: nil)
      label(unit, Locale.effective(locale))
    end

    # @return [String]
    def to_s
      rounded = round(@amount.decimal, @entry.ui_decimals, :floor)
      "#{@entry.symbol}|#{format_number(rounded, @entry.ui_decimals, false)}"
    end

    # @param unit [Symbol]
    # @return [BigDecimal]
    def in_unit(unit)
      unit_spec = @entry.display_unit(unit)
      @amount.decimal * Amount.coerce_decimal(unit_spec[:scale])
    end

    private

    def render_default(direction, decorated:, trim_zeros:, locale:)
      rounded = round(@amount.decimal, @entry.ui_decimals, direction)
      formatted = format_number(rounded, @entry.ui_decimals, resolve_trim(trim_zeros), locale)
      return formatted unless decorated

      decorate(formatted, nil, nil, locale)
    end

    def render_display_unit(unit, direction, decorated:, trim_zeros:, locale:)
      spec = @entry.display_unit(unit)
      scaled = @amount.decimal * Amount.coerce_decimal(spec[:scale])
      decimals = spec[:ui_decimals] || @entry.ui_decimals
      rounded = round(scaled, decimals, direction)
      formatted = format_number(rounded, decimals, resolve_trim(trim_zeros, spec), locale)
      return formatted unless decorated

      decorate(formatted, unit, spec, locale)
    end

    # Places the number and its label with the template from
    # {Formattable#display_format}. Without a label there is nothing to place,
    # so the number is returned alone.
    def decorate(number, unit, spec, locale)
      label = label(unit, locale, spec)
      return number if label.nil? || label.empty?

      Formattable.fill(@amount.display_format(unit:, locale:), number:, label:)
    end

    def label(unit, locale, spec = nil)
      spec ||= @entry.display_unit(unit) if unit
      if spec
        return spec[:symbol] || @entry.display_symbol unless locale

        Locale.unit_label(@entry, unit.to_sym, spec, locale)
      else
        locale ? Locale.type_label(@entry, locale) : @entry.display_symbol
      end
    end

    def round(value, decimals, direction)
      factor = BigDecimal(10)**decimals
      scaled = value * factor
      truncated = direction == :ceil ? scaled.ceil : scaled.floor
      truncated / factor
    end

    def format_number(value, decimals, trim, locale = nil)
      str = format("%.#{decimals}f", value)
      str = str.sub(/(\.\d*?)0+\z/, '\1').chomp('.') if trim
      locale ? Locale.apply(str, locale) : str
    end

    def resolve_trim(call_site, spec = nil)
      return call_site unless call_site.nil?
      return spec[:trim_zeros] if spec&.key?(:trim_zeros)

      @entry.trim_zeros
    end
  end
end
