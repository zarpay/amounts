# =============================================================================
# GoldAmount: a custom Amount subclass for the :GOLD type
# =============================================================================
#
# The `amounts` gem usually models type identity through the registry rather
# than class inheritance. The `class:` registry option is an opt-in escape
# hatch for the small set of cases where a type genuinely needs methods of
# its own — most often domain conventions that don't translate to other
# types.
#
# GoldAmount demonstrates the pattern. It adds a single helper, `purity_for`,
# that scales the gold weight by a karat purity factor. Bullion-quality work
# wants this; treasury balances and log counts do not — so it lives here, not
# on the base Amount class.
#
# Once the type is registered with `class: GoldAmount` (see the registry
# initializer), every entry point that takes a symbol at runtime returns a
# GoldAmount:
#
#   Amount.new("1.0", :GOLD).class             # => GoldAmount
#   Amount.of_gold("1.0").class                   # => GoldAmount
#   Amount.parse("GOLD|1.0").class             # => GoldAmount
#   Amount.load(payload).class                 # => GoldAmount
#   Vault::GoldBar.find(id).weight.class       # => GoldAmount
#
# Subclass identity is preserved through arithmetic, `split`/`allocate`,
# `abs`, `-@`, and identity-symbol `.to(:GOLD)`. Cross-type conversions
# (`gold.to(:USD)`) return a plain Amount because `:USD` has no custom class.

class GoldAmount < Amount
  # Mapping of common karat grades to their decimal purity factor. 24k is
  # essentially pure; 18k is 75% gold by mass; 22k is the 91.6% bullion
  # standard used by Sovereigns and Krugerrands.
  KARAT_PURITIES = {
    "24k" => BigDecimal("1.0"),
    "22k" => BigDecimal("0.916"),
    "18k" => BigDecimal("0.750")
  }.freeze

  # Returns the *fine gold content* in troy ounces for a given karat.
  #
  #   GoldAmount.new("10", :GOLD).purity_for("18k")
  #   # => 7.500   (10 oz t of 18k jewelry contains 7.5 oz t of pure gold)
  #
  # The result is a BigDecimal — a quantity, not an Amount — because the
  # caller may want to compare it to a target threshold or feed it back into
  # arithmetic without wrapping.
  def purity_for(karat)
    raise ArgumentError, "unknown karat #{karat}" unless KARAT_PURITIES.key?(karat)

    decimal * KARAT_PURITIES.fetch(karat)
  end
end
