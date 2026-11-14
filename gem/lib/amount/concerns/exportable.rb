# frozen_string_literal: true

class Amount
  # Concern: exporting the registry for a client in another language to
  # mirror. See {Manifest} for what the export holds.
  module Exportable
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level methods extended onto any class that does `include Exportable`.
    module ClassMethods
      # The registry as a JSON-ready manifest: its types, its default rates,
      # and for each locale in `locales` every translation the core looks up.
      # The `@zarpay/amounts` JavaScript client is built from it.
      #
      # @param locales [Array<Symbol, String>] locales to resolve (needs I18n)
      # @return [Hash{String=>Object}]
      # @raise [ArgumentError] when locales are given without I18n loaded
      # @example
      #   Amount.manifest["types"]["USDC"]["decimals"]
      #   # => 6
      #
      # @example Serving it from a Rails controller
      #   render json: Amount.manifest(locales: I18n.available_locales)
      def manifest(locales: [])
        Manifest.new(registry, locales:).to_h
      end
    end
  end
end
