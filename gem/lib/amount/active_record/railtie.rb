# frozen_string_literal: true

class Amount
  module ActiveRecord
    class Railtie < ::Rails::Railtie
      generators do
        require_relative "../../../generators/amount/active_record/registry_generator"
      end
    end
  end
end
