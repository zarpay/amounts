# frozen_string_literal: true

class Amount
  # Converts amounts to and from the versioned hash payload.
  class Serializer
    VERSION = 1

    def self.dump(amount)
      {
        v: VERSION,
        atomic: amount.atomic.to_s,
        symbol: amount.symbol.to_s
      }
    end

    def self.load(payload)
      payload = payload.transform_keys(&:to_sym)
      validate_version!(payload[:v])

      Amount.new(payload.fetch(:atomic), payload.fetch(:symbol), from: :atomic)
    rescue KeyError => e
      raise InvalidInput, "amount payload missing key: #{e.key}"
    end

    def self.validate_version!(version)
      return if version.nil? || version == VERSION

      raise InvalidInput, "unsupported amount serialization version: #{version}"
    end

    private_class_method :validate_version!
  end
end
