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
  #
  #   - bulk intake through `upsert_all`, with `amount_column_values`
  #     turning each manifest row's amounts into their columns
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
    # Bulk intake
    # -------------------------------------------------------------------------
    #
    # The vault receives bars by manifest, one row per bar keyed by serial.
    # `upsert_all` writes the whole manifest in one statement: new serials
    # are inserted, and bars already held get their weight and appraisal
    # re-recorded.
    #
    # `upsert_all` skips attribute writers and takes column values only, so
    # `amount_column_values` turns each row's amounts into their columns
    # first: `weight` into `weight_atomic`, `appraisal` into
    # `appraisal_atomic` and `appraisal_symbol`. Like any bulk write it skips
    # validations; a weight in a symbol other than GOLD raises instead.
    # Every row needs the same keys, so pass `appraisal: nil` for a bar with
    # no appraisal.

    def self.receive_manifest(rows)
      upsert_all(rows.map { |row| amount_column_values(row) }, unique_by: :serial)
    end

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

    # Rendered string in the requested unit (or default oz_t). Pass `locale:`
    # to format the number with that locale's delimiter and separator (read
    # from I18n `number.format`); without it the output is unchanged.
    #
    #   weight_label                               # => "12.5000 oz t"
    #   weight_label(unit: :gram)                  # => "388.79 g"
    #   weight_label(unit: :kg, direction: :ceil)  # => "0.38880 kg"
    #   weight_label(unit: :gram, locale: :de)     # => "388,79 Gramm"
    def weight_label(unit: nil, direction: :floor, locale: nil)
      return nil if weight.nil?

      opts = { direction: direction, locale: locale }.compact
      opts[:unit] = unit if unit
      weight.ui(**opts)
    end

    # Appraisal value for display, optionally localized.
    #
    #   appraisal_label(locale: :de)  # => "25.000,00 $" (non-breaking space, from de.yml)
    def appraisal_label(locale: nil)
      return nil if appraisal.nil?

      locale ? appraisal.ui(locale: locale) : appraisal.ui
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
