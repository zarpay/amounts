# frozen_string_literal: true

class Amount
  # Concern: the class-level entry points that turn strings into amounts.
  #
  # Two inputs, two parsers:
  #
  # - {Amount.parse} reads the compact machine format (`USDC|1.50`) that
  #   `to_s` writes. See {Parser}.
  # - {Amount.parse_ui} reads what a person typed, in a locale's number
  #   format. See {UiParser}.
  module Parsing
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level methods extended onto any class that does `include Parsing`.
    module ClassMethods
      # Parses the compact client-facing string representation.
      #
      # Accepts either the default form `SYMBOL|amount` or the explicit
      # versioned form `v1:SYMBOL|amount`.
      #
      # @param str [String]
      # @return [Amount]
      # @raise [InvalidInput]
      # @example Parsing the default compact format
      #   Amount.parse("USDC|1.50")
      #
      # @example Parsing the explicit versioned compact format
      #   Amount.parse("v1:USDC|1.50")
      def parse(str)
        Parser.new(str).parse
      end

      # Parses text typed by a person, in a locale's number format.
      #
      # The effective locale is `locale:`, then `I18n.locale` when
      # `Amount.localize` is true, else plain parsing (`.` decimal, no
      # delimiters). Accepts surrounding whitespace, a leading `-` or `+`,
      # delimiters in groups of three, and the type's label (any plural form)
      # at either end. Never rounds.
      #
      # @param input [String]
      # @param symbol [Symbol, String]
      # @param locale [Symbol, String, nil]
      # @return [Amount] an instance of the type's registered class
      # @raise [InvalidInput] for too many decimals, misplaced delimiters, a
      #   repeated separator, another type's label, or empty input
      # @raise [Registry::UnknownType] for an unregistered symbol
      # @example
      #   Amount.parse_ui("1.500,50", :USD, locale: :de) # => USD|1500.50
      def parse_ui(input, symbol, locale: nil)
        UiParser.new(input, symbol, locale).parse
      end
    end
  end
end
