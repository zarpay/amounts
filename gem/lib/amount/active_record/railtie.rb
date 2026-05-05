# frozen_string_literal: true

class Amount
  module ActiveRecord
    class Railtie < ::Rails::Railtie
      initializer "amount.active_record" do
        require "amount/active_record"
      end

      generators do
        require_relative "../../generators/amount/active_record/registry_generator"
      end
    end
  end
end
