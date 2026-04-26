module Treasury
  # ===========================================================================
  # Treasury::Holding
  #
  # The flagship model for the harness. It exercises:
  #
  #   - the `has_amount` macro in BOTH shapes:
  #       * multi-symbol  (balance, reserve)
  #       * fixed-symbol  (fee, pinned to :SOL)
  #
  #   - the full `validates :x, amount: { ... }` option matrix:
  #       symbol:, greater_than:, greater_than_or_equal_to:,
  #       less_than:, less_than_or_equal_to:, allow_nil:
  #
  #   - generated query scopes (`where_balance_*`, `balance_in`),
  #     plus a custom scope (`rich`) layered on top
  #
  #   - lifecycle callbacks that read from the gem's dirty-tracking
  #     helpers (`balance_changed?`, `saved_change_to_balance`)
  #
  #   - an instance method (`total_in`) that demonstrates cross-type
  #     conversion via `.to(:SYMBOL)`
  #
  # The base table comes from the `CreateTreasuryHoldings` migration. Every
  # column shape and default this model relies on is documented there.
  # ===========================================================================
  class Holding < ApplicationRecord
    self.table_name = "treasury_holdings"

    # -------------------------------------------------------------------------
    # has_amount declarations
    # -------------------------------------------------------------------------
    #
    # `balance` and `reserve` are multi-symbol (any registered symbol may be
    # stored). `fee` is fixed at :SOL — the writer accepts raw numerics for
    # fixed-symbol attributes only, because the symbol is already implied.

    has_amount :balance
    has_amount :fee, symbol: :SOL
    has_amount :reserve

    # -------------------------------------------------------------------------
    # Associations
    # -------------------------------------------------------------------------

    has_many :transfers,
      class_name:  "Treasury::Transfer",
      foreign_key: :holding_id,
      dependent:   :destroy

    # -------------------------------------------------------------------------
    # Validations
    # -------------------------------------------------------------------------
    #
    # Each attribute uses a different combination of validator options so the
    # spec suite can verify all of them.
    #
    # NB on threshold types:
    #   - For fixed-symbol attributes (`fee`), numeric thresholds are
    #     interpreted as UI values in the bound symbol. `greater_than: 0`
    #     means "0 SOL".
    #   - For multi-symbol attributes (`balance`, `reserve`), numeric
    #     thresholds are interpreted as UI values in the VALUE'S symbol at
    #     validation time. This is the 0.0.2 fix; before that, numeric
    #     thresholds on multi-symbol attributes raised a confusing error.
    #     We use compact-string thresholds here for explicitness.

    validates :owner, presence: true

    validates :balance, amount: {
      greater_than:          "USDC|0",
      less_than_or_equal_to: "USDC|1000000",
      allow_nil:             true
    }

    validates :fee, amount: {
      symbol:                   :SOL,
      greater_than_or_equal_to: 0,
      less_than:                100,
      allow_nil:                true
    }

    validates :reserve, amount: {
      symbol:                   :USDC,
      greater_than_or_equal_to: "USDC|1.25"
    }

    # -------------------------------------------------------------------------
    # Scopes
    # -------------------------------------------------------------------------
    #
    # `has_amount :balance` gave us:
    #
    #   where_balance(value)            exact match (auto-filters by symbol)
    #   where_balance_gt(value)         strict greater-than
    #   where_balance_gte(value)        inclusive greater-than-or-equal
    #   where_balance_lt(value)         strict less-than
    #   where_balance_lte(value)        inclusive less-than-or-equal
    #   where_balance_between(lo, hi)   inclusive range, single symbol
    #   balance_in(symbol)              filter by symbol only
    #
    # The custom scopes below layer domain meaning over the generated ones.

    scope :with_balance_in, ->(symbol) { balance_in(symbol) }
    scope :rich,            -> { where_balance_gte("USDC|1000") }

    # -------------------------------------------------------------------------
    # Callbacks + dirty-tracking demonstration
    # -------------------------------------------------------------------------
    #
    # `before_validation` defaults the SOL fee to zero on create using the
    # `class_attribute` introspection helper exposed by has_amount. Without
    # the guard, `||=` would interact with the writer's nil-clearing logic.
    #
    # `after_save` reads `saved_change_to_balance?` — one of the dirty
    # helpers has_amount generates per attribute — and pushes the
    # `[old_amount, new_amount]` pair into a per-record log. The spec for
    # this model uses the log to assert that the callback only fires when
    # the attribute actually changed.

    before_validation :default_fee_to_zero, on: :create
    after_save        :record_balance_change

    attr_reader :balance_change_log

    def initialize(*)
      super
      @balance_change_log = []
    end

    # Returns the sum of `balance` (if any) and `reserve`, both converted
    # into `target_symbol` via the registry's directional default rates.
    # If the holding has no balance, the call still works — it just returns
    # the converted reserve.
    #
    # Cross-type conversion goes through `.to(:SYMBOL)`, which uses
    # `register_default_rate` lookups. Conversion of an Amount whose symbol
    # has no registered class returns a plain Amount; conversion to a
    # symbol with `class:` (e.g. :GOLD) returns the registered subclass.
    def total_in(target_symbol)
      converted_balance = balance&.to(target_symbol)
      converted_reserve = reserve.to(target_symbol)

      converted_balance ? converted_balance + converted_reserve : converted_reserve
    end

    private

    def default_fee_to_zero
      self.fee ||= 0 if Holding.amount_attribute_definitions[:fee]
    end

    def record_balance_change
      return unless saved_change_to_balance?

      @balance_change_log << saved_change_to_balance
    end
  end
end
