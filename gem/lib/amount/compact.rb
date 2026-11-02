# frozen_string_literal: true

require "bigdecimal"

class Amount
  # Internal: compact notation for large numbers, used by `ui(compact: true)`.
  #
  # A number of at least one thousand is divided by the largest scale it
  # reaches (thousand, million, ... up to decillion, 10**33), rounded to a number of
  # significant digits in the given direction, trimmed of trailing zeros and
  # joined with a scale word:
  #
  # - when localizing, the word is `number.human.decimal_units.units.<scale>`
  #   (pluralized with the compacted number) joined by
  #   `number.human.decimal_units.format` (default `"%n %u"`), the keys Rails'
  #   `number_to_human` uses. A scale without a translation falls back to the
  #   short form below.
  # - otherwise the word is `K`, `M`, `B`, `T`, `Qa`, `Qi`, `Sx`, `Sp`, `Oc`,
  #   `No` or `Dc`, joined as `"%n%u"`.
  #
  # Numbers past decillions stay in decillions (`1500Dc`).
  #
  # Numbers below one thousand are not compacted; {Display} formats them as
  # usual.
  #
  # @example
  #   Amount::Compact.format(BigDecimal("1999999"), precision: 3, direction: :floor, locale: nil)
  #   # => "1.99M"
  module Compact
    DEFAULT_PRECISION = 3
    SHORT_FORMAT = "%n%u"
    LOCALE_FORMAT = "%n %u"
    LOCALE_FORMAT_KEY = "number.human.decimal_units.format"
    LOCALE_UNITS_KEY = "number.human.decimal_units.units"

    # [exponent, I18n key, short form], smallest first.
    SCALES = [
      [3, :thousand, "K"],
      [6, :million, "M"],
      [9, :billion, "B"],
      [12, :trillion, "T"],
      [15, :quadrillion, "Qa"],
      [18, :quintillion, "Qi"],
      [21, :sextillion, "Sx"],
      [24, :septillion, "Sp"],
      [27, :octillion, "Oc"],
      [30, :nonillion, "No"],
      [33, :decillion, "Dc"]
    ].freeze

    module_function

    # Reads the `compact:` option of `ui`.
    # @param option [Boolean, Hash, nil] `true`, `false`/`nil`, or
    #   `{ precision: Integer }`
    # @return [Integer, nil] significant digits, or `nil` when compact
    #   notation is off
    # @raise [ArgumentError] for anything else
    def precision(option)
      case option
      when nil, false then nil
      when true then DEFAULT_PRECISION
      when Hash then precision_from_hash(option)
      else raise ArgumentError, "compact: must be true, false or { precision: Integer }, got #{option.inspect}"
      end
    end

    # @param value [BigDecimal]
    # @return [Boolean] whether the number is large enough to compact
    def applies?(value)
      value.abs >= BigDecimal(10)**SCALES.first[0]
    end

    # The compacted number with its scale word, e.g. `"1.5M"` or
    # `"1,5 Mio."`. Call only when {applies?} is true.
    # @param value [BigDecimal]
    # @param precision [Integer] significant digits
    # @param direction [Symbol] `:floor` or `:ceil`, as in `ui`
    # @param locale [Symbol, String, nil]
    # @return [String]
    def format(value, precision:, direction:, locale:)
      index = SCALES.rindex { |exponent, _, _| value.abs >= BigDecimal(10)**exponent }
      loop do
        mantissa, decimals = round(value, SCALES[index][0], precision, direction)
        # Rounding up can reach the next scale: 999,999 ceils to 1000K, shown as 1M.
        if mantissa.abs >= 1000 && index < SCALES.length - 1
          index += 1
          next
        end

        return join(number(mantissa, decimals, locale), mantissa, SCALES[index], locale)
      end
    end

    # Divides by 10**exponent and rounds to `precision` significant digits.
    # Returns the mantissa and how many decimals it may show.
    def round(value, exponent, precision, direction)
      mantissa = value / (BigDecimal(10)**exponent)
      digits = [mantissa.abs.to_i.to_s.length, 1].max
      decimals = precision - digits
      [Display.round(mantissa, decimals, direction), [decimals, 0].max]
    end

    def number(mantissa, decimals, locale)
      str = mantissa.to_s("F")
      int, frac = str.split(".", 2)
      frac = frac.to_s[0, decimals].sub(/0+\z/, "")
      str = frac.empty? ? int : "#{int}.#{frac}"
      locale ? Locale.apply(str, locale) : str
    end

    def join(number, mantissa, scale, locale)
      _, key, short = scale
      word = locale && Locale.translate("#{LOCALE_UNITS_KEY}.#{key}", locale, "", mantissa)
      return Formattable.fill(SHORT_FORMAT, number:, label: short) if word.nil? || word.empty?

      Formattable.fill(locale_format(locale), number:, label: word)
    end

    def locale_format(locale)
      found = Locale.translate(LOCALE_FORMAT_KEY, locale, LOCALE_FORMAT)
      Formattable.valid_template?(found) ? found : LOCALE_FORMAT
    end

    def precision_from_hash(option)
      unknown = option.keys - [:precision]
      raise ArgumentError, "unknown compact: option(s) #{unknown.map(&:inspect).join(', ')}" unless unknown.empty?

      digits = option.fetch(:precision, DEFAULT_PRECISION)
      return digits if digits.is_a?(Integer) && digits.positive?

      raise ArgumentError, "compact: precision must be a positive Integer, got #{digits.inspect}"
    end

    private_class_method :round, :number, :join, :locale_format, :precision_from_hash
  end
end
