# frozen_string_literal: true

class Amount
  # Versioned hash serialization. `include Serialization` does both halves:
  # the instance side (`#to_h`) is mixed in directly, and the class-level
  # entry point (`Amount.load`) is auto-extended onto the including class
  # via the `included` hook below. The compact-string format is the
  # responsibility of {Amount::Parser}.
  module Serialization
    VERSION = 1

    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level methods automatically extended onto any class that does
    # `include Serialization`.
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
