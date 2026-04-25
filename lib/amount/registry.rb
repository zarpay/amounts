# frozen_string_literal: true

require "bigdecimal"
require "thread"
require_relative "registry/generated_constructors"

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
    class AlreadyRegistered < StandardError; end
    class InvalidDisplayUnit < StandardError; end
    class NoDefaultRate < StandardError; end
    class RegistryLocked < StandardError; end

    Entry = Struct.new(
      :symbol, :decimals, :display_symbol, :display_position,
      :ui_decimals, :display_units, :default_display, :amount_class,
      keyword_init: true
    )

    def initialize
      @entries = {}
      @default_rates = {}
      @generated_constructors = GeneratedConstructors.new
      @locked = false
      @lock = Mutex.new
    end

    # Registers a new fungible type.
    #
    # When the symbol is a valid Ruby method name after downcasing, an
    # ergonomic constructor is also generated on `Amount`, such as
    # `Amount.usdc("1.50")`.
    #
    # @param symbol [Symbol, String] registered type identifier
    # @param decimals [Integer] number of storage decimals
    # @param display_symbol [String] symbol used by UI helpers
    # @param display_position [Symbol] either `:prefix` or `:suffix`
    # @param ui_decimals [Integer] decimals displayed by default UI formatting
    # @param display_units [Hash, nil] optional display-only scaling definitions
    # @param default_display [Symbol, nil] optional default display unit key
    # @param class [Class, nil] optional custom `Amount` subclass
    # @return [void]
    # @raise [AlreadyRegistered] if the symbol is already registered or the
    #   generated constructor would collide with an existing method
    # @raise [RegistryLocked] if the registry has been locked
    # @example
    #   Amount.register :USDC,
    #     decimals: 6,
    #     display_symbol: "$",
    #     display_position: :prefix,
    #     ui_decimals: 2
    def register(symbol, decimals:, display_symbol: symbol.to_s, display_position: :suffix,
                 ui_decimals: decimals, display_units: nil, default_display: nil,
                 class: nil)
      symbol = symbol.to_sym

      @lock.synchronize do
        ensure_unlocked!
        raise AlreadyRegistered, "#{symbol} already registered" if @entries.key?(symbol)

        validate_display_units!(display_units, default_display) if display_units

        entry = Entry.new(
          symbol: symbol,
          decimals: decimals,
          display_symbol: display_symbol,
          display_position: display_position,
          ui_decimals: ui_decimals,
          display_units: display_units,
          default_display: default_display,
          amount_class: binding.local_variable_get(:class) || Amount
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
        @default_rates[[from, to]] = BigDecimal(rate.to_s)
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
      end
    end
  end
end
