module Yard
  # ===========================================================================
  # Yard::LogShipment
  #
  # The Timber cookbook is the simplest of the four domains — there's
  # exactly one fungible thing (LOGS), it has no fractional value, and the
  # interesting behavior is all in `split` / `allocate`.
  #
  # Because :LOGS is registered with `decimals: 0`, atomic value equals UI
  # value. There's no precision arithmetic to think about — just exact
  # integer division with a remainder that's always carried explicitly.
  #
  # Key features exercised:
  #
  #   - `decimals: 0` integer-style amounts
  #   - `split(n)` to divide a shipment evenly across a crew
  #   - `allocate(weights)` for proportional distribution
  #   - generated `where_total_gt(numeric)` scope (raw numerics work for
  #     fixed-symbol attributes because the symbol is implied)
  # ===========================================================================
  class LogShipment < ApplicationRecord
    self.table_name = "yard_log_shipments"

    has_amount :total, symbol: :LOGS

    validates :origin,    presence: true
    validates :total,     amount: { symbol: :LOGS, greater_than_or_equal_to: 0 }
    validates :crew_size, numericality: { greater_than: 0 }

    scope :heavy, -> { where_total_gt(50) }

    # -------------------------------------------------------------------------
    # Splitting and allocation
    # -------------------------------------------------------------------------
    #
    # The cookbook's central lesson: divisions return both parts AND the
    # leftover, so callers cannot accidentally drop a log on the floor.
    #
    #   parts, remainder = LogShipment.new(total: 10, crew_size: 3).split_evenly
    #   parts.map(&:atomic)        # => [3, 3, 3]
    #   remainder.atomic           # => 1
    #
    # The invariant `parts.sum(&:atomic) + remainder.atomic == total.atomic`
    # holds for every split / allocate, including negative totals (where
    # rounding is toward zero and the remainder takes the matching sign).

    def split_evenly
      total.split(crew_size)
    end

    def allocate(weights)
      total.allocate(weights)
    end
  end
end
