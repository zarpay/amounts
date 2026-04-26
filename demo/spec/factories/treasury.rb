# =============================================================================
# Treasury factories
# =============================================================================
#
# These factories double as a catalog of every input form the gem's
# ActiveRecord writer accepts:
#
#   - compact string                "USDC|10.00"
#   - Amount instance               Amount.sol("0.5")
#   - {atomic:, symbol:} hash       { atomic: 25_000_000, symbol: :USDC }
#   - raw numeric                   0.10            (fixed-symbol attrs only)
#   - nil                           clears both component columns
#
# Each trait below highlights one shape so spec authors can reach for the
# trait that matches the assertion they want to make.

FactoryBot.define do
  factory :treasury_holding, class: "Treasury::Holding" do
    sequence(:owner) { |n| "owner-#{n}" }

    # Default attributes use a compact string for `balance` and an Amount
    # instance for `fee`. Mixing forms in the default factory is deliberate
    # — it keeps the spec output readable while still exercising both code
    # paths on every build.
    balance { "USDC|10.00" }
    fee     { Amount.sol("0.5") }

    # Multi-symbol balance overridden to a USDC value above the "rich"
    # scope's threshold.
    trait :rich do
      balance { Amount.usdc("5000.00") }
    end

    # Multi-symbol balance switched to SOL — proves the scopes filter by
    # symbol correctly.
    trait :sol_balance do
      balance { Amount.sol("12.5") }
    end

    # Clears the multi-symbol balance entirely (both component columns
    # become NULL).
    trait :no_balance do
      balance { nil }
    end

    # Demonstrates the `{atomic:, symbol:}` hash input form. The writer
    # passes this through `Amount.load` after key normalization, so
    # versionless and string-keyed payloads also work.
    trait :hash_input do
      balance { { atomic: 25_000_000, symbol: :USDC } }
    end
  end

  factory :treasury_transfer, class: "Treasury::Transfer" do
    association :holding, factory: :treasury_holding

    gross      { "USDC|50.00" }
    # Fixed-symbol attributes (commission is :USDC) accept raw numerics
    # as UI values — the symbol is implied by the registry binding.
    commission { 0.10 }
    memo       { "test transfer" }

    trait :sol do
      gross { Amount.sol("1.0") }
    end
  end
end
