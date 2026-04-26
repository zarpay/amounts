module Treasury
  # ===========================================================================
  # Treasury::Transfer
  #
  # A money movement against a Treasury::Holding. Demonstrates:
  #
  #   - mixing fixed-symbol (commission, USDC) and multi-symbol (gross)
  #     attributes on a single record
  #
  #   - CONDITIONAL validations driven by an Amount predicate (`if:` block
  #     reading `gross&.symbol`) — useful when business rules only kick in
  #     for certain symbols
  #
  #   - same-type subtraction inside a regular instance method (`net`),
  #     including the fail-soft `same_type?` guard for cross-currency rows
  #
  #   - `where_*_between` and a derivative custom scope that takes a range
  # ===========================================================================
  class Transfer < ApplicationRecord
    self.table_name = "treasury_transfers"

    # -------------------------------------------------------------------------
    # has_amount declarations
    # -------------------------------------------------------------------------
    #
    # `gross` is multi-symbol so transfers in any currency are allowed.
    # `commission` is pinned to :USDC since the platform always charges
    # commission in dollars.

    has_amount :gross
    has_amount :commission, symbol: :USDC

    # -------------------------------------------------------------------------
    # Associations
    # -------------------------------------------------------------------------

    belongs_to :holding, class_name: "Treasury::Holding"

    # -------------------------------------------------------------------------
    # Validations
    # -------------------------------------------------------------------------
    #
    # The `if:` block on the gross validator demonstrates that the gem's
    # validator composes naturally with Rails' standard conditional
    # validation. We only enforce "gross > 0 USDC" when gross is actually
    # a USDC amount — for other currencies the threshold doesn't apply.

    validates :gross,      amount: { greater_than: "USDC|0" },           if: :gross_in_usdc?
    validates :commission, amount: { symbol: :USDC, greater_than_or_equal_to: 0 }

    # -------------------------------------------------------------------------
    # Scopes
    # -------------------------------------------------------------------------

    scope :large,        -> { where_gross_gt("USDC|100") }
    scope :within_range, ->(low, high) { where_gross_between(low, high) }

    # -------------------------------------------------------------------------
    # Domain methods
    # -------------------------------------------------------------------------

    # Returns gross - commission when both amounts share a symbol. If gross
    # is in a different currency than commission (e.g. gross in SOL,
    # commission always in USDC), there is no rate to bridge them and we
    # bail out with nil rather than raising. Callers decide how to surface
    # that gap.
    def net
      return nil if gross.nil? || commission.nil?
      return nil unless gross.same_type?(commission)

      gross - commission
    end

    private

    def gross_in_usdc?
      gross&.symbol == :USDC
    end
  end
end
