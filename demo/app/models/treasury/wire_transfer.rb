module Treasury
  # ===========================================================================
  # Treasury::WireTransfer
  #
  # A Treasury::Transfer sent by bank wire, stored in the same table through
  # single-table inheritance. Demonstrates:
  #
  #   - `has_amount` attributes INHERITED by a subclass: `gross` and
  #     `commission`, with their validations, scopes and introspection
  #     (`amount_attribute_definitions`, `amount_component_columns`)
  #
  #   - a subclass adding an amount of its OWN (`wire_fee`) that the parent
  #     class and its other subclasses never see
  # ===========================================================================
  class WireTransfer < Transfer
    # -------------------------------------------------------------------------
    # has_amount declarations
    # -------------------------------------------------------------------------
    #
    # The bank charges its wire fee in dollars, on top of the platform's
    # commission. Plain transfers have no wire fee, so the column is NULL
    # for them and `Transfer` doesn't declare it.

    has_amount :wire_fee, symbol: :USDC

    # -------------------------------------------------------------------------
    # Validations
    # -------------------------------------------------------------------------
    #
    # Added to the ones inherited from Transfer (commission >= 0 USDC, and
    # gross > 0 when gross is in USDC).

    validates :wire_fee, amount: { symbol: :USDC, greater_than_or_equal_to: 0, allow_nil: true }
  end
end
