# =============================================================================
# Reusable shared_examples for has_amount-backed models
# =============================================================================
#
# Three groups of assertions get repeated across every model spec:
#
#   - round-trip behavior of a multi-symbol amount column
#   - input-form coverage of a fixed-symbol amount column
#   - Comparable sortability of a same-symbol Amount collection
#
# Lifting each group into a shared_examples keeps the model specs focused
# on their own domain rules. Each example takes the attribute name (and a
# sample value) so it can drive the introspection helpers exposed by
# `has_amount`:
#
#   ModelClass.amount_atomic_column(:balance)   # => "balance_atomic"
#   ModelClass.amount_symbol_column(:balance)   # => "balance_symbol"
#
# Use them via `it_behaves_like`:
#
#   it_behaves_like "a multi-symbol amount column", :balance, sample: "USDC|17.25"

RSpec.shared_examples "a multi-symbol amount column" do |attribute, sample:|
  it "round-trips an Amount through #{attribute}" do
    record = subject
    record.public_send("#{attribute}=", sample)
    record.save!
    record.reload

    expect(record).to have_amount_column(attribute, sample)
  end

  it "clears both component columns when assigned nil" do
    record = subject
    record.public_send("#{attribute}=", sample)
    record.save!

    record.public_send("#{attribute}=", nil)
    record.save!
    record.reload

    expect(record.public_send(attribute)).to be_nil

    atomic = record.public_send(described_class.amount_atomic_column(attribute))
    symbol = record.public_send(described_class.amount_symbol_column(attribute))

    expect(atomic).to be_nil
    expect(symbol).to be_nil
  end

  it "tracks dirty changes on #{attribute}" do
    record = subject
    record.public_send("#{attribute}=", sample)

    expect(record.public_send("#{attribute}_changed?")).to be(true)
    expect(record.public_send("#{attribute}_change")).to be_an(Array)
  end
end

RSpec.shared_examples "a fixed-symbol amount column" do |attribute, symbol:, sample_ui:|
  it "accepts a raw numeric and stores #{symbol}" do
    record = subject
    record.public_send("#{attribute}=", sample_ui.to_f)
    record.save!
    record.reload

    expect(record.public_send(attribute)).to be_amount_of(symbol)
    expect(record.public_send(attribute).decimal).to eq(BigDecimal(sample_ui.to_s))
  end

  it "rejects an Amount of a different symbol" do
    record = subject
    other  = (symbol == :USDC ? :SOL : :USDC)
    record.public_send("#{attribute}=", Amount.new(sample_ui.to_s, other))

    expect(record).not_to be_valid
    expect(record.errors[attribute].join).to match(/expected #{symbol}/i)
  end
end

RSpec.shared_examples "a sortable Amount" do
  it "sorts via Comparable" do
    sorted = [
      Amount.new("3", symbol),
      Amount.new("1", symbol),
      Amount.new("2", symbol)
    ].sort

    expect(sorted.map(&:atomic)).to eq(sorted.map(&:atomic).sort)
  end
end
