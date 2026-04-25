# frozen_string_literal: true

class Amount
  # Versioned hash serialization. The instance side (`#to_h`) is included on
  # `Amount`; the class-level entry point (`Amount.load`) comes from
  # `extend Serialization::ClassMethods`. The compact-string format is the
  # responsibility of {Amount::Parser}.
  module Serialization
    VERSION = 1

    # Class-level methods made available to any class that does
    # `extend Amount::Serialization::ClassMethods`. Currently only `Amount`
    # itself.
    module ClassMethods
      # @param payload [Hash]
      # @return [Amount]
      # @raise [Amount::InvalidInput] for unsupported versions or missing keys
      # @example
      #   Amount.load(v: 1, atomic: "1500000", symbol: "USDC")
      def load(payload)
        payload = payload.transform_keys(&:to_sym)
        validate_serialization_version!(payload[:v])

        Amount.new(payload.fetch(:atomic), payload.fetch(:symbol), from: :atomic)
      rescue KeyError => e
        raise Amount::InvalidInput, "amount payload missing key: #{e.key}"
      end

      private

      def validate_serialization_version!(version)
        return if version.nil? || version == VERSION

        raise Amount::InvalidInput, "unsupported amount serialization version: #{version}"
      end
    end

    # @return [Hash]
    # @example
    #   Amount.usdc("1.50").to_h
    #   # => { v: 1, atomic: "1500000", symbol: "USDC" }
    def to_h
      {
        v: VERSION,
        atomic: @atomic.to_s,
        symbol: @symbol.to_s
      }
    end
  end
end
