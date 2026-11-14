# frozen_string_literal: true

class Amount
  # Versioned hash serialization. `include Serializable` does both halves:
  # the instance side (`#to_h`) is mixed in directly, and the class-level
  # entry point (`Amount.load`) is auto-extended onto the including class
  # via the `included` hook below. The compact-string format is the
  # responsibility of {Amount::Parser}.
  module Serializable
    VERSION = 1

    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level methods automatically extended onto any class that does
    # `include Serializable`.
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
    #   Amount.of_usdc("1.50").to_h
    #   # => { v: 1, atomic: "1500000", symbol: "USDC" }
    def to_h
      {
        v: VERSION,
        atomic: @atomic.to_s,
        symbol: @symbol.to_s
      }
    end

    # The exact compact string: whole units with exactly `decimals` places.
    # Unlike `to_s`, it ignores the display settings and never rounds, so
    # `Amount.parse` reads it back exactly.
    #
    # @return [String]
    # @example
    #   Amount.of_usdc("1.5").as_json # => "USDC|1.500000"
    def as_json(*)
      whole, fraction = atomic.abs.divmod(10**decimals)
      number = decimals.zero? ? whole.to_s : "#{whole}.#{fraction.to_s.rjust(decimals, '0')}"

      "#{symbol}|#{'-' if atomic.negative?}#{number}"
    end

    # Without ActiveSupport, the `json` library writes an object through
    # `to_s`, so `to_json` goes through {#as_json} explicitly.
    #
    # @return [String]
    def to_json(*args)
      as_json.to_json(*args)
    end
  end
end
