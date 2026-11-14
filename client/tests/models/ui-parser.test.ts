import { describe, expect, it } from "vitest";

import { UiParser } from "@/models/ui-parser.js";
import { testAmounts, thrown } from "@tests/helpers/fixtures.js";

const registry = testAmounts().registry;

/** The atomic value of `input` typed for `symbol`, in `locale` or plainly. */
function parse(input: string, symbol: string, locale: string | null = null): bigint {
  const entry = registry.lookup(symbol);
  const table = locale === null ? null : registry.locale(locale);
  const parser = new UiParser(input, entry, table);

  return parser.parse();
}

describe("UiParser", () => {
  describe("number formats", () => {
    it("reads plain input with a point", () => {
      const atomic = parse("1500.50", "USD");

      expect(atomic).toBe(150050n);
    });

    it("reads English delimiters", () => {
      const atomic = parse("1,500.50", "USD", "en");

      expect(atomic).toBe(150050n);
    });

    it("reads German delimiters", () => {
      const atomic = parse("1.500,50", "USD", "de");

      expect(atomic).toBe(150050n);
    });

    it("reads French space delimiters", () => {
      const atomic = parse("1 500,50", "USD", "fr");

      expect(atomic).toBe(150050n);
    });

    it("reads a non-breaking space as a space delimiter", () => {
      const atomic = parse("1 500,50", "USD", "fr");

      expect(atomic).toBe(150050n);
    });

    it("reads several delimiter groups", () => {
      const atomic = parse("1,500,000.5", "USD", "en");

      expect(atomic).toBe(150000050n);
    });

    it("reads a German decimal comma", () => {
      const atomic = parse("1,5", "USD", "de");

      expect(atomic).toBe(150n);
    });

    it("reads a whole number for a type without decimals", () => {
      const atomic = parse("7", "LOGS");

      expect(atomic).toBe(7n);
    });

    it("refuses delimiters when parsing plainly", () => {
      const error = thrown(() => parse("1,500.50", "USD"));

      expect(error).toMatchObject({ message: 'cannot parse "1,500.50" as USD: is not a number' });
    });

    it("refuses misplaced delimiters", () => {
      const error = thrown(() => parse("15,00.50", "USD", "en"));

      expect(error).toMatchObject({ message: 'cannot parse "15,00.50" as USD: is not a number' });
    });
  });

  describe("signs and whitespace", () => {
    it("ignores surrounding whitespace", () => {
      const atomic = parse("  12.5  ", "USD");

      expect(atomic).toBe(1250n);
    });

    it("reads a minus", () => {
      const atomic = parse("-12.5", "USD");

      expect(atomic).toBe(-1250n);
    });

    it("drops a plus", () => {
      const atomic = parse("+12.5", "USD");

      expect(atomic).toBe(1250n);
    });

    it("allows space after the sign", () => {
      const atomic = parse("- 12.5", "USD");

      expect(atomic).toBe(-1250n);
    });
  });

  describe("labels", () => {
    it("strips a prefix label", () => {
      const atomic = parse("$12.50", "USD");

      expect(atomic).toBe(1250n);
    });

    it("reads a sign after a prefix label", () => {
      const atomic = parse("$-12.50", "USD");

      expect(atomic).toBe(-1250n);
    });

    it("reads a sign before a prefix label", () => {
      const atomic = parse("-$12.50", "USD");

      expect(atomic).toBe(-1250n);
    });

    it("refuses a second sign", () => {
      const error = thrown(() => parse("-$-12.50", "USD"));

      expect(error).toMatchObject({ message: 'cannot parse "-$-12.50" as USD: is not a number' });
    });

    it("strips a suffix label", () => {
      const atomic = parse("12.50 $", "USD");

      expect(atomic).toBe(1250n);
    });

    it("strips a plural form", () => {
      const atomic = parse("3 searches", "SEARCHES");

      expect(atomic).toBe(3n);
    });

    it("strips a singular form", () => {
      const atomic = parse("1 search", "SEARCHES");

      expect(atomic).toBe(1n);
    });

    it("strips a translated label in its locale", () => {
      const atomic = parse("3 Suchen", "SEARCHES", "de");

      expect(atomic).toBe(3n);
    });

    it("strips a translated type label", () => {
      const atomic = parse("2 Feinunze", "GOLD", "de");

      expect(atomic).toBe(200000000n);
    });

    it("refuses a translated label when parsing plainly", () => {
      const error = thrown(() => parse("3 Suchen", "SEARCHES"));

      expect(error).toMatchObject({
        message: 'cannot parse "3 Suchen" as SEARCHES: is not a number',
      });
    });

    it("refuses another type's label", () => {
      const error = thrown(() => parse("12 SOL", "USD"));

      expect(error).toMatchObject({ message: 'cannot parse "12 SOL" as USD: is not a number' });
    });

    it("refuses a label alone", () => {
      const error = thrown(() => parse("$", "USD"));

      expect(error).toMatchObject({ message: 'cannot parse "$" as USD: is not a number' });
    });
  });

  describe("rejections", () => {
    it("refuses empty input", () => {
      const error = thrown(() => parse("", "USD"));

      expect(error).toMatchObject({ message: 'cannot parse "" as USD: is empty' });
    });

    it("refuses blank input", () => {
      const error = thrown(() => parse("   ", "USD"));

      expect(error).toMatchObject({ message: 'cannot parse "   " as USD: is empty' });
    });

    it("refuses more decimals than the type stores, never rounding", () => {
      const error = thrown(() => parse("1.234", "USD"));

      expect(error).toMatchObject({
        message: 'cannot parse "1.234" as USD: has more than 2 decimal places',
      });
    });

    it("refuses any decimals for a type without them", () => {
      const error = thrown(() => parse("7.0", "LOGS"));

      expect(error).toMatchObject({
        message: 'cannot parse "7.0" as LOGS: has more than 0 decimal places',
      });
    });

    it("refuses a repeated separator", () => {
      const error = thrown(() => parse("1.2.3", "USD"));

      expect(error).toMatchObject({
        message: 'cannot parse "1.2.3" as USD: a decimal separator is used twice',
      });
    });

    it("refuses a trailing separator", () => {
      const error = thrown(() => parse("1.", "USD"));

      expect(error).toMatchObject({ message: 'cannot parse "1." as USD: is not a number' });
    });

    it("refuses a leading separator", () => {
      const error = thrown(() => parse(".5", "USD"));

      expect(error).toMatchObject({ message: 'cannot parse ".5" as USD: is not a number' });
    });

    it("refuses an exponent", () => {
      const error = thrown(() => parse("1.5e2", "USD"));

      expect(error).toMatchObject({ message: 'cannot parse "1.5e2" as USD: is not a number' });
    });

    it("refuses letters", () => {
      const error = thrown(() => parse("abc", "USD"));

      expect(error).toMatchObject({ code: "INVALID_INPUT" });
    });
  });
});
