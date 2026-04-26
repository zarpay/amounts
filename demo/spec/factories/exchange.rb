# =============================================================================
# Exchange factories
# =============================================================================
#
# Default trade swaps EMBER for USD using the EMBER<->USD directional
# rate. Traits cover the other interesting shapes:
#
#   :silver_for_usd  exercises the asymmetric SILVER->USD rate
#   :usdc_for_sol    exercises the bidirectional USDC<->SOL rate
#   :settled         exercises the after(:create) callback hook by
#                    immediately calling `settle!` to populate the
#                    fixed-symbol `settlement` column

FactoryBot.define do
  factory :exchange_trade, class: "Exchange::Trade" do
    sequence(:counterparty) { |n| "cp-#{n}" }

    sold   { Amount.ember("100") }
    bought { Amount.usd("25") }

    trait :silver_for_usd do
      sold   { Amount.silver("1.0") }
      bought { Amount.usd("30") }
    end

    trait :usdc_for_sol do
      sold   { Amount.usdc("150") }
      bought { Amount.sol("1.0") }
    end

    trait :settled do
      after(:create) { |trade| trade.settle! }
    end
  end
end
