# frozen_string_literal: true

require "bigdecimal"
require "thread"

class Amount
  # Stores registered amount types and default directional conversion rates.
  #
  # The registry is the configuration surface of the gem. Application code
  # normally uses the shared global instance exposed by {Amount.registry},
  # configures it during boot, and optionally calls {#lock!} when setup is
  # complete.
  #
  # @example Registering types at boot
  #   Amount.register :USDC, decimals: 6
  #
  #   Amount.register :USD, decimals: 2
  #
  #   Amount.register_default_rate :USD, :USDC, "1"
  #   Amount.registry.lock!
  class Registry
    class UnknownType < StandardError; end
    class NoDefaultRate < StandardError; end
    class RegistryLocked < StandardError; end
    class AlreadyRegistered < StandardError; end
    class InvalidDisplayUnit < StandardError; end
    class InvalidDisplaySymbol < StandardError; end

    Entry = Struct.new(
      :symbol,
      :decimals,
      :display_symbol,
      :label_key,
      :display_position,
      :display_format,
      :ui_decimals,
      :display_units,
      :default_display,
      :amount_class,
      :trim_zeros,
      keyword_init: true
    ) do
      # @param unit [Symbol, String]
      # @return [Hash] the display unit's spec
      # @raise [InvalidDisplayUnit] when the type has no such display unit
      def display_unit(unit)
        raise InvalidDisplayUnit, "#{symbol} has no display_units configured" unless display_units

        display_units.fetch(unit.to_sym) do
          raise InvalidDisplayUnit, "unknown display unit #{unit} for #{symbol}"
        end
      end
    end

    def initialize
      @entries       = {}
      @default_rates = {}
      @locked        = false

      @lock = Mutex.new
      @generated_constructors = GeneratedConstructors.new
    end

    # Registers a new fungible type.
    #
    # When the symbol is a valid Ruby method name after downcasing, an
    # ergonomic constructor is also generated on `Amount` with an `of_`
    # prefix, such as `Amount.of_usdc("1.50")`. The prefix avoids collisions
    # with existing methods like `Object#try` (added by ActiveSupport).
    #
    # @param symbol [Symbol, String] registered type identifier
    # @param decimals [Integer] number of storage decimals
    # @param display_symbol [String, Hash] symbol used by UI helpers. A hash
    #   (`{ one: "search", other: "searches" }`) gives plural forms and must
    #   have `:other`
    # @param label_key [String, Symbol, nil] I18n key for the unit label, used
    #   when localizing. Defaults to `amounts.units.<symbol downcased>`;
    #   a missing translation falls back to `display_symbol`
    # @param display_position [Symbol, nil] `:prefix` (`"$1.50"`) or `:suffix`
    #   (`"1.50 SOL"`, the default). Shorthand for the templates `"%u%n"` and
    #   `"%n %u"`; can't be combined with `display_format`
    # @param display_format [String, nil] template for decorated `ui` output,
    #   where `%n` is the formatted number (sign included) and `%u` the label,
    #   e.g. `"%n\u00A0%u"`. Used exactly as given. When localizing,
    #   `amounts.formats.<symbol downcased>` overrides it
    # @param ui_decimals [Integer] decimals displayed by default UI formatting
    # @param display_units [Hash, nil] optional display-only scaling definitions
    # @param default_display [Symbol, nil] optional default display unit key
    # @param trim_zeros [Boolean] strip trailing zeros from UI output
    # @param class [Class, nil] optional custom `Amount` subclass
    # @return [void]
    # @raise [AlreadyRegistered] if the symbol is already registered or the
    #   generated constructor would collide with an existing method
    # @raise [RegistryLocked] if the registry has been locked
    # @raise [ArgumentError] if both `display_format` and `display_position`
    #   are given, or `display_format` is not a String containing `%n`
    # @example
    #   Amount.register :USDC,
    #     decimals: 6,
    #     display_symbol: "$",
    #     display_position: :prefix,
    #     ui_decimals: 2
    def register(symbol, decimals:, display_symbol: symbol.to_s, label_key: nil, display_position: nil,
                 display_format: nil, ui_decimals: decimals, display_units: nil, default_display: nil,
                 trim_zeros: false, class: nil)
      raise ArgumentError, "symbol must not be blank" if symbol.nil? || symbol.to_s.empty?

      symbol = symbol.to_sym

      @lock.synchronize do
        ensure_unlocked!
        raise AlreadyRegistered, "#{symbol} already registered" if @entries.key?(symbol)

        validate_display_symbol!(:display_symbol, display_symbol, InvalidDisplaySymbol)
        validate_display_format!(display_format, display_position) if display_format
        validate_display_units!(display_units, default_display) if display_units

        entry = Entry.new(
          symbol:,
          decimals:,
          display_symbol:,
          label_key: label_key&.to_s,
          display_position: display_format ? nil : (display_position || :suffix),
          display_format: display_format || Formattable.template_for(display_position),
          ui_decimals:,
          display_units:,
          default_display:,
          amount_class: binding.local_variable_get(:class) || Amount,
          trim_zeros:
        )

        @entries[symbol] = entry
        @generated_constructors.define_for(entry)
      end
    end

    # @param symbol [Symbol, String]
    # @return [Boolean]
    # @example
    #   Amount.registry.registered?(:USDC)
    #   # => true
    def registered?(symbol)
      @lock.synchronize { @entries.key?(symbol.to_sym) }
    end

    # @param symbol [Symbol, String]
    # @return [Entry]
    # @raise [UnknownType]
    # @example
    #   Amount.registry.lookup(:USDC).decimals
    #   # => 6
    def lookup(symbol)
      @lock.synchronize do
        @entries.fetch(symbol.to_sym) do
          raise UnknownType, "#{symbol} is not registered"
        end
      end
    end

    # @return [Array<Symbol>]
    # @example
    #   Amount.registry.symbols
    #   # => [:USDC, :USD]
    def symbols
      @lock.synchronize { @entries.keys }
    end

    # @return [void]
    # @raise [RegistryLocked] if the registry has been locked
    # @example
    #   Amount.registry.clear!
    def clear!
      @lock.synchronize do
        ensure_unlocked!
        @generated_constructors.remove_all
        @entries.clear
        @default_rates.clear
      end
    end

    # @param from [Symbol, String]
    # @param to [Symbol, String]
    # @param rate [String, Numeric, BigDecimal]
    # @return [void]
    # @raise [RegistryLocked] if the registry has been locked
    # @example
    #   Amount.register_default_rate :USD, :USDC, "1"
    def register_default_rate(from, to, rate)
      from = from.to_sym
      to = to.to_sym

      lookup(from)
      lookup(to)

      @lock.synchronize do
        ensure_unlocked!
        @default_rates[[from, to]] = Amount.coerce_decimal(rate)
      end
    end

    # @param from [Symbol, String]
    # @param to [Symbol, String]
    # @return [BigDecimal]
    # @raise [NoDefaultRate]
    # @example
    #   Amount.registry.default_rate(:USD, :USDC)
    #   # => 0.1e1
    def default_rate(from, to)
      @lock.synchronize do
        @default_rates.fetch([from.to_sym, to.to_sym]) do
          raise NoDefaultRate, "no default rate for #{from} -> #{to}; pass rate: explicitly"
        end
      end
    end

    # @param from [Symbol, String]
    # @param to [Symbol, String]
    # @return [Boolean]
    # @example
    #   Amount.registry.default_rate?(:USD, :USDC)
    #   # => true
    def default_rate?(from, to)
      @lock.synchronize { @default_rates.key?([from.to_sym, to.to_sym]) }
    end

    # @return [void]
    # @example Locking the global registry after initialization
    #   Amount.registry.lock!
    def lock!
      @lock.synchronize do
        @locked = true
      end
    end

    # @return [Boolean]
    # @example
    #   Amount.registry.locked?
    #   # => true
    def locked?
      @lock.synchronize { @locked }
    end

    # @return [void]
    def activate_generated_methods!
      @lock.synchronize do
        @generated_constructors.activate(@entries)
      end
    end

    # @return [void]
    def remove_generated_methods!
      @lock.synchronize do
        @generated_constructors.remove_all
      end
    end

    private

    def ensure_unlocked!
      raise RegistryLocked, "registry is locked" if @locked
    end

    def validate_display_format!(format, position)
      raise ArgumentError, "pass display_format or display_position, not both" if position
      return if Formattable.valid_template?(format)

      raise ArgumentError, "display_format must be a String containing %n"
    end

    def validate_display_units!(units, default)
      unless units.is_a?(Hash) && !units.empty?
        raise InvalidDisplayUnit, "display_units must be a non-empty hash"
      end

      if default && !units.key?(default)
        raise InvalidDisplayUnit, "default_display #{default} not in display_units"
      end

      units.each do |key, spec|
        unless spec.is_a?(Hash) && spec.key?(:scale)
          raise InvalidDisplayUnit, "display_unit #{key} must have :scale"
        end

        validate_unit_format!(key, spec) if spec.key?(:format)
        validate_display_symbol!("display_unit #{key} :symbol", spec[:symbol], InvalidDisplayUnit) if spec[:symbol]
      end
    end

    def validate_unit_format!(key, spec)
      if spec.key?(:position)
        raise InvalidDisplayUnit, "display_unit #{key} takes :format or :position, not both"
      end
      return if Formattable.valid_template?(spec[:format])

      raise InvalidDisplayUnit, "display_unit #{key} :format must be a String containing %n"
    end

    def validate_display_symbol!(name, value, error)
      return unless value.is_a?(Hash)

      unless value.key?(:other)
        raise error, "#{name} hash must have an :other key (got #{value.keys.inspect})"
      end

      bad = value.reject { |k, v| k.is_a?(Symbol) && v.is_a?(String) }
      return if bad.empty?

      raise error, "#{name} hash must map Symbol plural keys to String labels (got #{bad.inspect})"
    end
  end
end
