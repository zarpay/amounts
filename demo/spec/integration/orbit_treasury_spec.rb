require "rails_helper"

# =============================================================================
# Orbit Treasury — end-to-end cookbook scenario
# =============================================================================
#
# This is one of four cookbook integration specs. Each one walks through a
# realistic chain of operations on its domain so the gem's features are
# visible in context, not as isolated unit tests.
#
# Orbit Treasury covers:
#   - funding a USDC holding to its migration-default reserve
#   - posting USDC transfers and reading derived amounts (`net`)
#   - cross-type conversion through the registered USDC<->USD rate
#   - SOL fees on the same record (fixed-symbol attribute)
#   - sub-treasuries by symbol via the `balance_in(:SOL)` scope
#   - the `have_amount_column` matcher proving both atomic and symbol
#     columns round-trip correctly

RSpec.describe "Orbit Treasury cookbook scenario", :integration, type: :model do
  let(:holding) { create(:treasury_holding, balance: "USDC|1000.00") }

  it "lets a user fund, transfer, and aggregate treasury balances" do
    expect(holding.balance).to eq_amount("USDC|1000.0")

    create(:treasury_transfer, holding: holding, gross: "USDC|150.00", commission: "USDC|0.50")
    create(:treasury_transfer, holding: holding, gross: "USDC|10.00", commission: "USDC|0.50")

    nets = holding.transfers.map(&:net)
    expect(nets).to all(be_amount_of(:USDC))
    expect(nets.first).to eq_amount("USDC|149.5")
    expect(nets.last).to eq_amount("USDC|9.5")
  end

  it "round-trips a balance through the database with both component columns" do
    expect(holding).to have_amount_column(:balance, "USDC|1000.0")
    expect(holding).to have_amount_column(:reserve, "USDC|1.25")
  end

  it "converts a balance to USD via the registered default rate" do
    converted = holding.balance.to(:USD)
    expect(converted).to be_amount_of(:USD)
    expect(converted.decimal).to eq(BigDecimal("1000"))
  end

  it "registers and validates SOL fees on the same record" do
    holding.fee = Amount.of_sol("0.5")
    holding.save!
    expect(holding.fee).to be_approximately_amount(:SOL, "0.5", within: "0.0001")
  end

  it "supports a SOL-only sub-treasury" do
    sol_holding = create(:treasury_holding, :sol_balance)
    expect(Treasury::Holding.balance_in(:SOL)).to include(sol_holding)
  end
end
