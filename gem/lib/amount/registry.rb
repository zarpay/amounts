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
    class NoDefaultRate < StandardError; end
    class RegistryLocked < StandardError; end
    class AlreadyRegistered < StandardError; end
    class InvalidDisplayUnit < StandardError; end

    Entry = Struct.new(
      :symbol,
      :decimals,
      :display_symbol,
      :display_position,
      :ui_decimals,
      :display_units,
      :default_display,
      :amount_class,
      :trim_zeros,
      keyword_init: true
    )

    def initialize
      @entries       = {}
      @default_rates = {}
      @locked        = false
      @resolver      = nil

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
    # @param display_symbol [String] symbol used by UI helpers
    # @param display_position [Symbol] either `:prefix` or `:suffix`
    # @param ui_decimals [Integer] decimals displayed by default UI formatting
    # @param display_units [Hash, nil] optional display-only scaling definitions
    # @param default_display [Symbol, nil] optional default display unit key
    # @param trim_zeros [Boolean] strip trailing zeros from UI output
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
                 trim_zeros: false, class: nil)
      raise ArgumentError, "symbol must not be blank" if symbol.nil? || symbol.to_s.empty?

      symbol = symbol.to_sym

      @lock.synchronize do
        ensure_unlocked!
        raise AlreadyRegistered, "#{symbol} already registered" if @entries.key?(symbol)

        validate_display_units!(display_units, default_display) if display_units

        entry = Entry.new(
          symbol:,
          decimals:,
          display_symbol:,
          display_position:,
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
      sym = symbol.to_sym
      entry = @lock.synchronize { @entries[sym] }
      return entry if entry

      entry = resolve_and_fetch(sym)
      return entry if entry

      raise UnknownType, "#{symbol} is not registered"
    end

    # Registers a resolver invoked when {#lookup} misses, BEFORE it raises
    # {UnknownType}. The block receives the missing symbol and is expected to
    # register it as a side effect (e.g. from a database row); lookup then
    # retries once. This turns the registry into a read-through cache: a
    # process that booted before a type was registered can resolve it lazily
    # instead of raising — useful when types are created at runtime and the
    # registry is per-process in-memory state. Pass no block to clear it.
    #
    # The resolver runs WITHOUT the registry lock held (it will call
    # {#register}, which locks) and is guarded against re-entrancy per thread,
    # so a resolver that itself triggers a miss cannot recurse forever. A
    # resolver that raises is swallowed and the original {UnknownType} is raised.
    #
    # @yieldparam symbol [Symbol] the missing type
    # @return [void]
    # @example Resolve unknown types from a database
    #   Amount.registry.resolve_missing do |symbol|
    #     Token.for_amount_key(symbol)&.register_amount_type
    #   end
    def resolve_missing(&block)
      @lock.synchronize { @resolver = block }
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
        @resolver = nil
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

    # Runs the missing-type resolver (if any) outside the lock and returns the
    # entry it registered, or nil. Per-thread re-entrancy guard prevents a
    # resolver that triggers its own lookup miss from recursing; a raising
    # resolver falls through to nil so lookup surfaces the real UnknownType.
    def resolve_and_fetch(sym)
      resolver = @lock.synchronize { @resolver }
      return nil unless resolver

      guard = (Thread.current[:amount_registry_resolving] ||= [])
      return nil if guard.include?(sym)

      guard.push(sym)
      begin
        resolver.call(sym)
      rescue StandardError
        return nil
      ensure
        guard.delete(sym)
      end

      @lock.synchronize { @entries[sym] }
    end

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
