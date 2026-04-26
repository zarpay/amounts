module Vault
  # ===========================================================================
  # Vault::GoldBar
  #
  # The Auric cookbook's centerpiece. This model is where `display_units`,
  # `in_unit`, custom-class round-trip, and `split` / `allocate` come
  # together end-to-end.
  #
  # Key features exercised:
  #
  #   - fixed-symbol `:GOLD` attribute backed by a `class: GoldAmount`
  #     registry entry — every read returns a real GoldAmount instance
  #     with `purity_for(...)` available on it
  #
  #   - `display_units` rendering through the model:
  #       weight_label                               oz_t (default)
  #       weight_label(unit: :gram)                  scaled to grams
  #       weight_label(unit: :kg, direction: :ceil)  rounded toward +inf
  #
  #   - raw scaled BigDecimal access via `in_unit` for callers who want
  #     to do their own formatting or feed the value back into arithmetic
  #
  #   - `split(parts)` / `allocate(weights)` to divide a single bar across
  #     multiple buyers without losing atomic precision
  #
  #   - shoulda-matchers presence + uniqueness on the serial
  # ===========================================================================
  class GoldBar < ApplicationRecord
    self.table_name = "vault_gold_bars"

    # -------------------------------------------------------------------------
    # has_amount declarations
    # -------------------------------------------------------------------------
    #
    # `weight` is fixed-symbol :GOLD. Since :GOLD is registered with
    # `class: GoldAmount`, the reader returns a GoldAmount instance every
    # time — including after `find` / `reload`. Subclass identity survives
    # arithmetic, split, and allocate.
    #
    # `appraisal` is multi-symbol so a bar can be valued in any currency.

    has_amount :weight, symbol: :GOLD
    has_amount :appraisal

    # -------------------------------------------------------------------------
    # Validations
    # -------------------------------------------------------------------------

    validates :serial,    presence: true, uniqueness: true
    validates :weight,    amount: { symbol: :GOLD, greater_than: 0 }
    validates :appraisal, amount: { greater_than: "USDC|0", allow_nil: true }

    # -------------------------------------------------------------------------
    # Display helpers
    # -------------------------------------------------------------------------
    #
    # Thin wrappers that surface the gem's display API in a domain vocabulary.
    # The model could simply expose `weight` and let callers reach into
    # `weight.ui(unit: :gram)` themselves; defining helpers here is a style
    # choice that documents which display units the application actually
    # supports.

    # Raw BigDecimal in the requested unit (no rounding, no symbol).
    # Returns nil if weight is unset — useful for chaining without an
    # explicit nil-guard at the call site.
    def weight_in(unit)
      weight&.in_unit(unit)
    end

    # Rendered string in the requested unit (or default oz_t).
    #
    #   weight_label                               # => "12.5000 oz t"
    #   weight_label(unit: :gram)                  # => "388.79 g"
    #   weight_label(unit: :kg, direction: :ceil)  # => "0.38880 kg"
    def weight_label(unit: nil, direction: :floor)
      return nil if weight.nil?

      unit ? weight.ui(unit: unit, direction: direction) : weight.ui(direction: direction)
    end

    # -------------------------------------------------------------------------
    # Splitting and allocation
    # -------------------------------------------------------------------------
    #
    # Both helpers preserve the gem's `[parts, remainder]` invariant:
    # `parts.sum(&:atomic) + remainder.atomic == weight.atomic`.

    # Split into `parts` equal pieces. Returns `[Array<GoldAmount>, GoldAmount]`.
    def split_into(parts)
      weight.split(parts)
    end

    # Allocate proportionally by integer weights — e.g. `[1, 1, 2]` gives
    # the third party twice as much as the others. Returns
    # `[Array<GoldAmount>, GoldAmount]`.
    def allocate_by(weights)
      weight.allocate(weights)
    end
  end
end
