# frozen_string_literal: true

class Amount
  # Parses compact amount strings such as `USDC|1.50`.
  class Parser
    VERSION_PREFIX = /\A(v\d+):(.*)\z/
    SUPPORTED_VERSION = "v1"

    def initialize(input)
      @input = input
    end

    def parse
      symbol, value = parse_components
      validate!(symbol, value)

      Amount.new(value, symbol)
    rescue ArgumentError
      raise InvalidInput, "cannot parse #{@input.inspect}"
    end

    private

    def parse_components
      compact = @input.to_s
      versioned = compact.match(VERSION_PREFIX)
      return split_components(compact) unless versioned

      version, body = versioned.captures
      validate_version!(version)
      split_components(body)
    end

    def split_components(compact)
      compact.split("|", 2)
    end

    def validate_version!(version)
      return if version == SUPPORTED_VERSION

      raise InvalidInput, "cannot parse #{@input.inspect}"
    end

    def validate!(symbol, value)
      return unless symbol.nil? || value.nil? || symbol.empty? || value.empty?

      raise InvalidInput, "cannot parse #{@input.inspect}"
    end
  end
end
