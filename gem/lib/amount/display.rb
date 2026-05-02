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
    # @return [String]
    # @example
    #   Amount.usdc("1.50").ui                       # => "$1.50"
    #   Amount.usdc("1.50").ui(decorated: false)     # => "1.50"
    #   Amount.gold("1").ui(unit: :gram)             # => "31.10 g"
    #   Amount.gold("1").ui(unit: :gram, decorated: false)  # => "31.10"
    #   Amount.sol("2.5").ui(trim_zeros: true)       # => "2.5 SOL"
    def ui(unit: nil, direction: :floor, decorated: true, trim_zeros: nil)
      if unit
        render_display_unit(unit, direction, decorated:, trim_zeros:)
      else
        render_default(direction, decorated:, trim_zeros:)
      end
    end

    # @return [String]
    def to_s
      rounded = round(@amount.decimal, @entry.ui_decimals, :floor)
      "#{@entry.symbol}|#{format_number(rounded, @entry.ui_decimals, false)}"
    end

    # @param unit [Symbol]
    # @return [BigDecimal]
    def in_unit(unit)
      unit_spec = fetch_display_unit(unit)
      @amount.decimal * Amount.coerce_decimal(unit_spec[:scale])
    end

    private

    def render_default(direction, decorated:, trim_zeros:)
      rounded = round(@amount.decimal, @entry.ui_decimals, direction)
      formatted = format_number(rounded, @entry.ui_decimals, resolve_trim(trim_zeros))
      return formatted unless decorated

      apply_symbol(formatted, @entry.display_symbol, @entry.display_position)
    end

    def render_display_unit(unit, direction, decorated:, trim_zeros:)
      spec = fetch_display_unit(unit)
      scaled = @amount.decimal * Amount.coerce_decimal(spec[:scale])
      decimals = spec[:ui_decimals] || @entry.ui_decimals
      rounded = round(scaled, decimals, direction)
      formatted = format_number(rounded, decimals, resolve_trim(trim_zeros, spec))
      return formatted unless decorated

      apply_symbol(
        formatted,
        spec[:symbol] || @entry.display_symbol,
        spec[:position] || @entry.display_position
      )
    end

    def fetch_display_unit(unit)
      units = @entry.display_units
      unless units
        raise Registry::InvalidDisplayUnit, "#{@entry.symbol} has no display_units configured"
      end

      units.fetch(unit.to_sym) do
        raise Registry::InvalidDisplayUnit, "unknown display unit #{unit} for #{@entry.symbol}"
      end
    end

    def round(value, decimals, direction)
      factor = BigDecimal(10)**decimals
      scaled = value * factor
      truncated = direction == :ceil ? scaled.ceil : scaled.floor
      truncated / factor
    end

    def format_number(value, decimals, trim)
      str = format("%.#{decimals}f", value)
      trim ? str.sub(/(\.\d*?)0+\z/, '\1').chomp('.') : str
    end

    def resolve_trim(call_site, spec = nil)
      return call_site unless call_site.nil?
      return spec[:trim_zeros] if spec&.key?(:trim_zeros)

      @entry.trim_zeros
    end

    def apply_symbol(str, symbol, position)
      return str if symbol.nil? || symbol.empty?

      position == :prefix ? "#{symbol}#{str}" : "#{str} #{symbol}"
    end
  end
end
