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
    # @return [String]
    def ui(unit: nil, direction: :floor)
      unit ? render_display_unit(unit, direction) : render_default(direction)
    end

    # @return [String]
    def to_s
      "#{@entry.symbol}|#{@amount.decimal.to_s("F")}"
    end

    # @param unit [Symbol]
    # @return [BigDecimal]
    def in_unit(unit)
      unit_spec = fetch_display_unit(unit)
      @amount.decimal * Amount.coerce_decimal(unit_spec[:scale])
    end

    private

    def render_default(direction)
      rounded = round(@amount.decimal, @entry.ui_decimals, direction)
      apply_symbol(format("%.#{@entry.ui_decimals}f", rounded), @entry.display_symbol, @entry.display_position)
    end

    def render_display_unit(unit, direction)
      spec = fetch_display_unit(unit)
      scaled = @amount.decimal * Amount.coerce_decimal(spec[:scale])
      decimals = spec[:ui_decimals] || @entry.ui_decimals
      rounded = round(scaled, decimals, direction)

      apply_symbol(
        format("%.#{decimals}f", rounded),
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

    def apply_symbol(str, symbol, position)
      return str if symbol.nil? || symbol.empty?

      position == :prefix ? "#{symbol}#{str}" : "#{str} #{symbol}"
    end
  end
end
