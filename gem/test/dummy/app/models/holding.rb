# frozen_string_literal: true

class Holding < ActiveRecord::Base
  has_amount :amount
  has_amount :fee, symbol: :SOL
  has_amount :reserve
end
