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
      version = payload[:v] || payload["v"]
      validate_version!(version)

      Amount.new(
        payload.fetch(:atomic) { payload.fetch("atomic") },
        payload.fetch(:symbol) { payload.fetch("symbol") },
        from: :atomic
      )
    end

    def self.validate_version!(version)
      return if version.nil? || version == VERSION

      raise InvalidInput, "unsupported amount serialization version: #{version}"
    end

    private_class_method :validate_version!
  end
end
