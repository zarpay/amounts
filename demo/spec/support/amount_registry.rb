# =============================================================================
# Shared contexts for swapping registries during test runs
# =============================================================================
#
# Two contexts are exposed:
#
#   "with an isolated registry"   wraps the example in `Amount.with_registry`
#                                 with a brand-new, empty registry. Use this
#                                 when the spec wants to verify register /
#                                 lock! / clear! behavior without polluting
#                                 the application registry.
#
#   "with the application registry"
#                                 sanity-checks that the boot-time initializer
#                                 ran. Use this in specs that depend on the
#                                 production set of symbols and rates.
#
# `Amount.with_registry` was added specifically to support this pattern. The
# block-scoped swap restores the previous registry in an `ensure`, even if
# the example raises mid-run.

RSpec.shared_context "with an isolated registry" do
  around do |example|
    isolated = Amount::Registry.new
    Amount.with_registry(isolated) { example.run }
  end
end

RSpec.shared_context "with the application registry" do
  before do
    expect(Amount.registry.registered?(:USDC)).to be(true),
      "expected the application initializer to have registered USDC"
  end
end
