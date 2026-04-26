# frozen_string_literal: true

ActiveRecord::Schema.define(version: 1) do
  create_table :holdings, force: true do |t|
    t.amount :amount, null: true
    t.amount :fee, symbol: :SOL, null: true
    t.amount :reserve, precision: 40, default: "USDC|1.25", null: false
  end
end
