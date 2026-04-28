# =============================================================================
# Application-wide Amount type registry
# =============================================================================
#
# This file is the gem's configuration surface for the four cookbook scenarios
# this harness exercises:
#
#   - Treasury (Orbit cookbook)  : USDC + USD + SOL
#   - Vault    (Auric cookbook)  : GOLD with display_units (oz_t, gram, kg)
#                                  using a custom GoldAmount subclass
#   - Yard     (Timber cookbook) : LOGS, decimals: 0
#   - Exchange (Ember cookbook)  : EMBER + SILVER, asymmetric directional rates
#
# Every Amount.register call defines:
#
#   - a type identity that Amount instances carry (:USDC, :SOL, ...)
#   - storage configuration (decimals: how many atomic units per UI unit)
#   - default formatting (display_symbol, display_position, ui_decimals)
#   - optionally, a generated convenience constructor like `Amount.usdc(...)`
#     when the symbol downcases to a valid Ruby method name
#   - optionally, a custom Amount subclass via `class:` (see GoldAmount below)
#   - optionally, alternate display units via `display_units:` for unit-scaled
#     rendering without changing the underlying type identity
#
# Default rates are registered separately via `register_default_rate`. They
# power both `+` / `-` cross-type arithmetic and explicit `.to(:SYMBOL)`
# conversions. Rates are DIRECTIONAL — register both directions if both are
# needed. The gem deliberately does not invert a registered rate for you.
#
# `to_prepare` is used so the registration runs after autoloading has set up
# `GoldAmount` (referenced via `class:`). The early-return guard makes the
# block idempotent under Rails' code-reloading in development.

require "amount"
require "amount/active_record"

Rails.application.config.to_prepare do
  next if Amount.registry.registered?(:USDC)

  # ---------------------------------------------------------------------------
  # Treasury / Orbit cookbook
  # ---------------------------------------------------------------------------
  #
  # USDC and USD share a "$" prefix. USDC's six decimals match the on-chain
  # token; USD's two decimals match the legal cent.
  #
  # SOL uses 9 decimals (lamports) and a "SOL" suffix.

  Amount.register :USDC,
    decimals:         6,
    display_symbol:   "$",
    display_position: :prefix,
    ui_decimals:      2

  Amount.register :USD,
    decimals:         2,
    display_symbol:   "$",
    display_position: :prefix,
    ui_decimals:      2

  Amount.register :SOL,
    decimals:         9,
    display_symbol:   "SOL",
    display_position: :suffix,
    ui_decimals:      4,
    trim_zeros:       true

  # ---------------------------------------------------------------------------
  # Vault / Auric cookbook
  # ---------------------------------------------------------------------------
  #
  # GOLD ships with three display units:
  #
  #   :oz_t  troy ounce (the storage unit; scale = 1)
  #   :gram  scaled by 31.1035 (one troy ounce in grams)
  #   :kg    scaled by 0.0311035 (one troy ounce in kilograms)
  #
  # Each unit overrides ui_decimals for sensible default precision. The
  # underlying TYPE is still :GOLD — display_units only change presentation,
  # they do not introduce new fungible types.
  #
  # `class: GoldAmount` tells the registry to dispatch every entry point
  # (Amount.new, Amount.parse, Amount.load, the ActiveRecord adapter) to
  # GoldAmount instead of the bare Amount class. This means
  #
  #   Amount.gold("1.0").class             # => GoldAmount
  #   Amount.new("1.0", :GOLD).class       # => GoldAmount      (since 0.0.2)
  #   Amount.parse("GOLD|1.0").class       # => GoldAmount      (since 0.0.2)
  #   Vault::GoldBar.first.weight.class    # => GoldAmount      (since 0.0.2)

  Amount.register :GOLD,
    decimals:         8,
    display_symbol:   "oz t",
    display_position: :suffix,
    ui_decimals:      4,
    display_units: {
      oz_t: { scale: 1,           symbol: "oz t", ui_decimals: 4 },
      gram: { scale: "31.1035",   symbol: "g",    ui_decimals: 2 },
      kg:   { scale: "0.0311035", symbol: "kg",   ui_decimals: 5 }
    },
    default_display: :oz_t,
    class:           GoldAmount

  # ---------------------------------------------------------------------------
  # Yard / Timber cookbook
  # ---------------------------------------------------------------------------
  #
  # LOGS uses decimals: 0 — there's no fractional log. The atomic value is
  # exactly the count. This makes split / allocate behave like classic integer
  # division with explicit remainder, which is the cookbook's central lesson.

  Amount.register :LOGS,
    decimals:         0,
    display_symbol:   "logs",
    display_position: :suffix

  # ---------------------------------------------------------------------------
  # Exchange / Ember cookbook
  # ---------------------------------------------------------------------------
  #
  # EMBER is a fictional in-game token. SILVER mirrors GOLD's display-unit
  # vocabulary so the same UI patterns apply across precious metals.
  #
  # Note that SILVER does NOT use a custom subclass — only GOLD does. That
  # asymmetry exists so the harness covers both shapes.

  Amount.register :EMBER,
    decimals:         4,
    display_symbol:   "EMB",
    display_position: :suffix,
    ui_decimals:      4

  Amount.register :SILVER,
    decimals:         6,
    display_symbol:   "oz t",
    display_position: :suffix,
    ui_decimals:      4,
    display_units: {
      oz_t: { scale: 1,           symbol: "oz t", ui_decimals: 4 },
      gram: { scale: "31.1035",   symbol: "g",    ui_decimals: 2 },
      kg:   { scale: "0.0311035", symbol: "kg",   ui_decimals: 5 }
    },
    default_display: :oz_t

  # ---------------------------------------------------------------------------
  # Directional default rates
  # ---------------------------------------------------------------------------
  #
  # Each pair below enables either `.to(:TARGET)` conversion or implicit
  # cross-type arithmetic in the registered direction.
  #
  # The asymmetry between EMBER and SILVER is intentional:
  #
  #   - EMBER has both directions registered, so `usd + ember` works AND
  #     `ember + usd` works.
  #   - SILVER has only `:SILVER -> :USD` registered, so `silver.to(:USD)`
  #     works but `usd.to(:SILVER)` raises NoDefaultRate. This exercises the
  #     gem's explicit-by-design rate model.

  Amount.register_default_rate :USD,    :USDC,  "1"
  Amount.register_default_rate :USDC,   :USD,   "1"
  Amount.register_default_rate :SOL,    :USDC,  "150.00"
  Amount.register_default_rate :USDC,   :SOL,   "0.00666666"
  Amount.register_default_rate :EMBER,  :USD,   "0.25"
  Amount.register_default_rate :USD,    :EMBER, "4"
  Amount.register_default_rate :SILVER, :USD,   "30.00"

  # ---------------------------------------------------------------------------
  # Locking
  # ---------------------------------------------------------------------------
  #
  # Locking the registry after boot means accidental re-registration in a
  # request cycle raises `Registry::RegistryLocked`. We only lock in
  # production because tests rely on `Amount.with_registry { ... }` to swap
  # in disposable registries for isolation.

  Amount.registry.lock! if Rails.env.production?
end
