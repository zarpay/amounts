# =============================================================================
# Yard factories
# =============================================================================
#
# LOGS uses decimals: 0, so the writer accepts raw integers naturally —
# atomic value equals UI value, no floating-point gymnastics. The traits
# below exist mostly to cover specific split / allocate edge cases.

FactoryBot.define do
  factory :yard_log_shipment, class: "Yard::LogShipment" do
    origin    { "north-fork" }
    total     { 100 }   # raw integer, accepted because :total is fixed-symbol
    crew_size { 4 }

    # 10 logs across a 3-person crew — the canonical "3, 3, 3 with 1
    # remainder" test of the split invariant.
    trait :uneven do
      total     { 10 }
      crew_size { 3 }
    end

    # Demonstrates the Amount-instance input form on a fixed-symbol attr.
    trait :amount_input do
      total { Amount.logs(50) }
    end
  end
end
