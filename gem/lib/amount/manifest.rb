# frozen_string_literal: true

class Amount
  # Writes a registry as a manifest: a JSON-ready Hash with everything the
  # core reads at runtime, for a client in another language to mirror (the
  # `@zarpay/amounts` JavaScript client reads it).
  #
  # Types are written with the `Amount.register` option names. Every I18n
  # lookup the core makes is resolved for each requested locale, so a client
  # needs neither I18n nor its key conventions. The fallbacks (a missing label
  # to `display_symbol`, a missing format to the registered template) are left
  # to the client, which applies them as the gem does.
  #
  # @example
  #   Amount::Manifest.new(Amount.registry, locales: [:de]).to_h["types"]["USD"]["decimals"]
  #   # => 2
  class Manifest
    VERSION = 1

    # @param registry [Amount::Registry]
    # @param locales [Array<Symbol, String>] locales to resolve (needs I18n)
    # @raise [ArgumentError] when locales are given without I18n loaded
    def initialize(registry, locales: [])
      Locale.require_i18n! unless locales.empty?

      @registry = registry
      @locales = locales
    end

    # @return [Hash{String=>Object}]
    def to_h
      {
        "v" => VERSION,
        "types" => @registry.symbols.to_h { |symbol| [symbol.to_s, type(@registry.lookup(symbol))] },
        "rates" => @registry.default_rates.map { |(from, to), rate| rate_row(from, to, rate) },
        "locales" => @locales.to_h { |locale| [locale.to_s, locale_table(locale)] }
      }
    end

    private

    def type(entry)
      {
        "decimals" => entry.decimals,
        "display_symbol" => label(entry.display_symbol),
        "display_format" => entry.display_format,
        "ui_decimals" => entry.ui_decimals,
        "trim_zeros" => entry.trim_zeros ? true : false,
        "display_units" => entry.display_units&.to_h { |unit, spec| [unit.to_s, display_unit(spec)] },
        "default_display" => entry.default_display&.to_s
      }
    end

    def display_unit(spec)
      {
        "scale" => Amount.coerce_decimal(spec[:scale]).to_s("F"),
        "symbol" => label(spec[:symbol]),
        "ui_decimals" => spec[:ui_decimals],
        "format" => spec[:format] || (spec[:position] && Formattable.template_for(spec[:position])),
        "trim_zeros" => unit_trim_zeros(spec)
      }
    end

    # `nil` when the unit doesn't set it, so the client falls back to the type.
    def unit_trim_zeros(spec)
      return unless spec.key?(:trim_zeros)

      spec[:trim_zeros] ? true : false
    end

    def rate_row(from, to, rate)
      { "from" => from.to_s, "to" => to.to_s, "rate" => rate.to_s("F") }
    end

    def locale_table(locale)
      {
        "number" => Locale.number_format(locale).transform_keys(&:to_s),
        "compact" => compact_table(locale),
        "types" => @registry.symbols.to_h { |symbol| [symbol.to_s, type_table(@registry.lookup(symbol), locale)] }
      }
    end

    def compact_table(locale)
      units = Compact::SCALES.to_h do |_, key, _|
        [key.to_s, label(lookup("#{Compact::LOCALE_UNITS_KEY}.#{key}", locale))]
      end

      { "format" => Compact.locale_format(locale), "units" => units }
    end

    def type_table(entry, locale)
      downcased = entry.symbol.to_s.downcase
      units = (entry.display_units || {}).to_h do |unit, spec|
        [unit.to_s, unit_table(downcased, unit, spec, locale)]
      end

      {
        "label" => label(lookup(entry.label_key || "amounts.units.#{downcased}", locale)),
        "format" => template(lookup("amounts.formats.#{downcased}", locale)),
        "units" => units
      }
    end

    def unit_table(downcased, unit, spec, locale)
      {
        "label" => label(lookup(spec[:label_key] || "amounts.display_units.#{downcased}.#{unit}", locale)),
        "format" => template(lookup("amounts.display_unit_formats.#{downcased}.#{unit}", locale))
      }
    end

    def lookup(key, locale)
      ::I18n.t(key.to_s, locale:, default: nil)
    end

    # A String, or a plural Hash with String keys. Anything else is not a
    # label the core could display, so it is written as `nil`.
    def label(value)
      case value
      when String then value
      when Hash then value.select { |_, form| form.is_a?(String) }.transform_keys(&:to_s)
      end
    end

    def template(value)
      value if Formattable.valid_template?(value)
    end
  end
end
