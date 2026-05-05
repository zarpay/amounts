# =============================================================================
# Vault factories
# =============================================================================
#
# `weight` is fixed-symbol :GOLD with `class: GoldAmount`. We feed it a
# compact string by default so the writer goes through `Amount.parse`,
# which correctly returns a GoldAmount instance for the registered class.
#
# `appraisal` is multi-symbol — the default factory uses USDC, but you can
# override to USD or SOL or whatever your test demands.

FactoryBot.define do
  factory :vault_gold_bar, class: "Vault::GoldBar" do
    sequence(:serial) { |n| "AU-#{n.to_s.rjust(6, '0')}" }

    weight    { "GOLD|1.0" }
    appraisal { "USDC|2000.00" }

    # 100 oz t bar — useful for split / allocate tests where remainders
    # need to be visible.
    trait :heavy do
      weight { Amount.of_gold("100") }
    end

    # No appraisal yet — the default-factory price is dropped, the bar
    # remains valid (appraisal is allow_nil).
    trait :unappraised do
      appraisal { nil }
    end
  end
end
