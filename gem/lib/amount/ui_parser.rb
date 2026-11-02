# frozen_string_literal: true

class Amount
  # Internal: parses the text a person types into a form field, optionally in
  # a locale's number format. Exact: never rounds, never goes through Float.
  class UiParser
    # @param input [#to_s]
    # @param symbol [Symbol, String]
    # @param locale [Symbol, String, nil]
    def initialize(input, symbol, locale)
      @input = input
      @entry = Amount.registry.lookup(symbol)
      @locale = Locale.effective(locale)
      format = @locale ? Locale.number_format(@locale) : { delimiter: "", separator: "." }
      @delimiter = format[:delimiter].to_s
      @separator = format[:separator].to_s
    end

    # @return [Amount]
    def parse
      text = strip(@input.to_s)
      fail_with("is empty") if text.empty?
      original = text

      sign, text = take_sign(text)
      @signed = text != original
      unlabeled = strip_label(text)
      # "$-1.50": a sign may follow a prefix label, but not as a second sign
      sign, unlabeled = take_sign(unlabeled) if sign.empty? && unlabeled != text && !@signed
      text = unlabeled
      value = atomic(text)
      Amount.new(sign.empty? ? value : -value, @entry.symbol)
    end

    private

    def fail_with(reason)
      raise InvalidInput, "cannot parse #{@input.inspect} as #{@entry.symbol}: #{reason}"
    end

    def strip(str)
      str.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
    end

    # @return [Array(String, String)] "-" or "" (a "+" is dropped), and the rest
    def take_sign(text)
      match = text.match(/\A([+-])[[:space:]]*(.*)\z/m)
      return ["", text] unless match

      [match[1] == "-" ? "-" : "", match[2]]
    end

    # Removes one label (the longest match) from either end.
    def strip_label(text)
      labels.each do |label|
        if text.start_with?(label)
          return strip(text.delete_prefix(label))
        elsif text.end_with?(label)
          return strip(text.delete_suffix(label))
        end
      end
      text
    end

    # Every form of the type's label: `display_symbol` (and its plural
    # forms), plus the locale's translation when localizing.
    def labels
      found = forms(@entry.display_symbol)
      found += forms(translation) if @locale
      found.map(&:to_s).reject(&:empty?).uniq.sort_by { |label| -label.length }
    end

    def translation
      key = @entry.label_key || "amounts.units.#{@entry.symbol.to_s.downcase}"
      ::I18n.t(key.to_s, locale: @locale, default: nil)
    end

    def forms(label)
      case label
      when Hash then label.values.grep(String)
      when String then [label]
      else []
      end
    end

    # @return [Integer] atomic units, unsigned
    def atomic(text)
      whole, fraction, extra = text.split(@separator, -1)
      fail_with("a decimal separator is used twice") if extra
      fail_with("is not a number") unless whole&.match?(whole_pattern)
      fraction ||= ""
      fail_with("is not a number") if text.include?(@separator) && fraction.empty?
      fail_with("is not a number") unless fraction.match?(/\A\d*\z/)
      if fraction.length > @entry.decimals
        fail_with("has more than #{@entry.decimals} decimal places")
      end

      digits = whole.gsub(/\D/, "") + fraction.ljust(@entry.decimals, "0")
      digits.to_i
    end

    def whole_pattern
      return /\A\d+\z/ if @delimiter.empty?

      glue = @delimiter.match?(/\A[[:space:]]+\z/) ? "[[:space:]]" : Regexp.escape(@delimiter)
      /\A(?:\d+|\d{1,3}(?:#{glue}\d{3})+)\z/
    end
  end
end
