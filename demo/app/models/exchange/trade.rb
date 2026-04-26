module Exchange
  # ===========================================================================
  # Exchange::Trade
  #
  # The Ember cookbook's central object. A trade has three Amount fields:
  #
  #   sold        — what was given up (multi-symbol, required)
  #   bought      — what was received (multi-symbol, required)
  #   settlement  — USD-equivalent for accounting (fixed-symbol :USD,
  #                  populated lazily via `settle!`)
  #
  # The interesting gem features here are about CROSS-TYPE behavior:
  #
  #   - directional default rates: the registry initializer registers
  #     EMBER<->USD in both directions but only SILVER->USD. The model
  #     gracefully handles the asymmetry; the spec proves it does.
  #
  #   - explicit `.to(:SYMBOL, rate:)` for one-off conversions that don't
  #     match the registered default
  #
  #   - implied-rate calculation: `implied_rate` divides bought by sold,
  #     coercing through whatever rate path is available
  #
  #   - graceful nil return on `NoDefaultRate` — the harness's preference
  #     for UI affordances over hard errors
  # ===========================================================================
  class Trade < ApplicationRecord
    self.table_name = "exchange_trades"

    # -------------------------------------------------------------------------
    # has_amount declarations
    # -------------------------------------------------------------------------

    has_amount :sold
    has_amount :bought
    has_amount :settlement, symbol: :USD

    # -------------------------------------------------------------------------
    # Validations
    # -------------------------------------------------------------------------
    #
    # Multi-symbol attribute thresholds must be Amount instances or compact
    # strings — raw numerics on multi-symbol attrs raise "raw numeric
    # assignment requires a fixed symbol" during threshold coercion. We
    # use compact-string thresholds here ("EMBER|0") for explicitness.
    #
    # The `if:` blocks restrict the threshold to EMBER trades. Other
    # currencies skip these specific checks (and rely on whatever other
    # validations apply at the controller / service layer).

    validates :counterparty, presence: true

    validates :sold,
      amount: { greater_than: "EMBER|0" },
      if:     -> { sold&.symbol == :EMBER }

    validates :bought,
      amount: { greater_than: "EMBER|0" },
      if:     -> { bought&.symbol == :EMBER }

    # -------------------------------------------------------------------------
    # Domain methods
    # -------------------------------------------------------------------------

    # Returns the BigDecimal ratio `bought / sold` after coercing both into
    # the receiver's symbol. Useful for deriving the price of a trade in
    # the unit of whatever was sold.
    #
    # Returns nil when:
    #   - either side is nil or zero (zero would otherwise raise
    #     ZeroDivisionError)
    #   - no rate path can coerce `bought` into `sold`'s symbol (e.g. an
    #     EMBER<->SILVER trade, since neither directional rate is registered)
    def implied_rate
      return nil if sold.nil? || bought.nil? || sold.zero?

      bought_in_sold = bought.to(sold.symbol)
      bought_in_sold / sold
    rescue Amount::Registry::NoDefaultRate
      nil
    end

    # Records the USD-equivalent of `sold` into the settlement column.
    # Without an explicit rate it uses the registered default; with one
    # it bypasses the registry — useful when the trade was negotiated at
    # a non-market rate (e.g. an OTC deal).
    def settle!(rate: nil)
      return self.settlement = nil if sold.nil?

      self.settlement = rate ? sold.to(:USD, rate: rate) : sold.to(:USD)
      save!
      settlement
    end
  end
end
