import type { AmountInput } from "@/types.js";

import { describe, expect, it } from "vitest";

import { Display } from "@/models/display.js";
import { testAmounts, thrown } from "@tests/helpers/fixtures.js";

const amounts = testAmounts();
const germanAmounts = testAmounts({ locale: "de" });

/** The display of an amount built by the plain client. */
function display(symbol: string, value: AmountInput): Display {
  const amount = amounts.of(symbol, value);

  return new Display(amount);
}

/** The display of an amount built by a client whose locale is German. */
function germanDisplay(symbol: string, value: AmountInput): Display {
  const amount = germanAmounts.of(symbol, value);

  return new Display(amount);
}

describe("Display", () => {
  describe("ui", () => {
    describe("rounding", () => {
      it("pads to the display decimals", () => {
        const usdc = display("USDC", "1.5");
        const text = usdc.ui();

        expect(text).toBe("$1.50");
      });

      it("rounds down by default", () => {
        const usdc = display("USDC", "1.239");
        const text = usdc.ui();

        expect(text).toBe("$1.23");
      });

      it("rounds up with ceil", () => {
        const usdc = display("USDC", "1.239");
        const text = usdc.ui({ direction: "ceil" });

        expect(text).toBe("$1.24");
      });

      it("rounds a negative value toward zero, like its positive", () => {
        const usdc = display("USDC", "-1.234");
        const text = usdc.ui();

        expect(text).toBe("$-1.23");
      });

      it("rounds a negative value away from zero with ceil", () => {
        const usdc = display("USDC", "-1.239");
        const text = usdc.ui({ direction: "ceil" });

        expect(text).toBe("$-1.24");
      });

      it("writes a tiny negative value that rounds to zero without a sign", () => {
        const usdc = display("USDC", "-0.001");
        const text = usdc.ui();

        expect(text).toBe("$0.00");
      });

      it("shows a tiny negative value as the smallest unit with ceil", () => {
        const usdc = display("USDC", "-0.001");
        const text = usdc.ui({ direction: "ceil" });

        expect(text).toBe("$-0.01");
      });

      it("rounds a negative value in a display unit toward zero", () => {
        const gold = display("GOLD", "-1");
        const text = gold.ui({ unit: "gram" });

        expect(text).toBe("-31.10 g");
      });

      it("compacts a negative value toward zero", () => {
        const tokens = display("TOKENS", -1_999_999n);
        const text = tokens.ui({ compact: true });

        expect(text).toBe("-1.99M TOKENS");
      });

      it("writes every digit of a value past a Float's precision", () => {
        const eth = display("ETH", "123456789012345678.123456789");
        const text = eth.ui();

        expect(text).toBe("123456789012345678.1234 ETH");
      });
    });

    describe("decoration", () => {
      it("omits the label when undecorated", () => {
        const usdc = display("USDC", "1.5");
        const text = usdc.ui({ decorated: false });

        expect(text).toBe("1.50");
      });

      it("places a suffix label", () => {
        const logs = display("LOGS", 5n);
        const text = logs.ui();

        expect(text).toBe("5 logs");
      });

      it("returns the number alone for an empty label", () => {
        const bare = display("BARE", "1");
        const text = bare.ui();

        expect(text).toBe("1.00");
      });

      it("agrees a plural label with one", () => {
        const searches = display("SEARCHES", 1n);
        const text = searches.ui();

        expect(text).toBe("1 search");
      });

      it("uses the plural label for zero without a locale", () => {
        const searches = display("SEARCHES", 0n);
        const text = searches.ui();

        expect(text).toBe("0 searches");
      });

      it("uses the plural label for many", () => {
        const searches = display("SEARCHES", 2n);
        const text = searches.ui();

        expect(text).toBe("2 searches");
      });
    });

    describe("trimming zeros", () => {
      it("follows the type's setting", () => {
        const sol = display("SOL", "2.5");
        const text = sol.ui();

        expect(text).toBe("2.5 SOL");
      });

      it("drops the point for a whole number", () => {
        const sol = display("SOL", "3");
        const text = sol.ui();

        expect(text).toBe("3 SOL");
      });

      it("lets the call site override the type", () => {
        const sol = display("SOL", "2.5");
        const text = sol.ui({ trimZeros: false });

        expect(text).toBe("2.5000 SOL");
      });

      it("follows a display unit's setting", () => {
        const gold = display("GOLD", "1");
        const text = gold.ui({ unit: "kg" });

        expect(text).toBe("0.0311 kg");
      });
    });

    describe("display units", () => {
      it("scales to the unit with its decimals and label", () => {
        const gold = display("GOLD", "1");
        const text = gold.ui({ unit: "gram" });

        expect(text).toBe("31.10 g");
      });

      it("places the label by the unit's position", () => {
        const gold = display("GOLD", "1");
        const text = gold.ui({ unit: "grain" });

        expect(text).toBe("gr480");
      });

      it("falls back to the type's label", () => {
        const gold = display("GOLD", "1");
        const text = gold.ui({ unit: "oz_t" });

        expect(text).toBe("1.0000 oz t");
      });

      it("refuses an unknown unit", () => {
        const gold = display("GOLD", "1");
        const error = thrown(() => gold.ui({ unit: "stone" }));

        expect(error).toMatchObject({ message: "unknown display unit stone for GOLD" });
      });

      it("refuses a unit for a type without units", () => {
        const usd = display("USD", "1");
        const error = thrown(() => usd.ui({ unit: "gram" }));

        expect(error).toMatchObject({ message: "USD has no display_units configured" });
      });
    });

    describe("locales", () => {
      it("writes German delimiters", () => {
        const usd = display("USD", "1500.5");
        const text = usd.ui({ locale: "de" });

        expect(text).toBe("$1.500,50");
      });

      it("writes French delimiters", () => {
        const usd = display("USD", "1500.5");
        const text = usd.ui({ locale: "fr" });

        expect(text).toBe("$1 500,50");
      });

      it("uses the locale's template", () => {
        const eur = display("EUR", "12.5");
        const text = eur.ui({ locale: "de" });

        expect(text).toBe("12,50 €");
      });

      it("keeps the registered template without a locale template", () => {
        const eur = display("EUR", "12.5");
        const text = eur.ui({ locale: "en" });

        expect(text).toBe("€12.50");
      });

      it("uses a translated type label", () => {
        const gold = display("GOLD", "1");
        const text = gold.ui({ locale: "de" });

        expect(text).toBe("1,0000 Feinunze");
      });

      it("agrees a translated plural label with one", () => {
        const searches = display("SEARCHES", 1n);
        const text = searches.ui({ locale: "de" });

        expect(text).toBe("1 Suche");
      });

      it("agrees a translated plural label with many", () => {
        const searches = display("SEARCHES", 3n);
        const text = searches.ui({ locale: "de" });

        expect(text).toBe("3 Suchen");
      });

      it("uses a translated unit label", () => {
        const gold = display("GOLD", "1");
        const text = gold.ui({ unit: "gram", locale: "de" });

        expect(text).toBe("31,10 Gramm");
      });

      it("uses a translated unit template", () => {
        const gold = display("GOLD", "1");
        const text = gold.ui({ unit: "kg", locale: "de" });

        expect(text).toBe("0,0311 kg");
      });

      it("follows the client's locale when the call gives none", () => {
        const usd = germanDisplay("USD", "1500.5");
        const text = usd.ui();

        expect(text).toBe("$1.500,50");
      });

      it("lets the call's locale override the client's", () => {
        const usd = germanDisplay("USD", "1500.5");
        const text = usd.ui({ locale: "fr" });

        expect(text).toBe("$1 500,50");
      });

      it("refuses a locale the manifest lacks", () => {
        const usd = display("USD", "1");
        const error = thrown(() => usd.ui({ locale: "ja" }));

        expect(error).toMatchObject({ code: "UNKNOWN_LOCALE" });
      });
    });

    describe("compact", () => {
      it("compacts a large number with the label", () => {
        const usd = display("USD", "1500000");
        const text = usd.ui({ compact: true });

        expect(text).toBe("$1.5M");
      });

      it("compacts without the label when undecorated", () => {
        const tokens = display("TOKENS", 50_000_000n);
        const text = tokens.ui({ compact: true, decorated: false });

        expect(text).toBe("50M");
      });

      it("leaves a number below one thousand as usual", () => {
        const usd = display("USD", "999.99");
        const text = usd.ui({ compact: true });

        expect(text).toBe("$999.99");
      });

      it("rounds up across a scale with ceil", () => {
        const usd = display("USD", "999999.99");
        const text = usd.ui({ compact: true, direction: "ceil" });

        expect(text).toBe("$1M");
      });

      it("keeps the given precision", () => {
        const tokens = display("TOKENS", 1_234_567n);
        const text = tokens.ui({ compact: { precision: 2 } });

        expect(text).toBe("1.2M TOKENS");
      });

      it("compacts in a locale", () => {
        const tokens = display("TOKENS", 2_500_000n);
        const text = tokens.ui({ compact: true, locale: "de" });

        expect(text).toBe("2,5 Millionen TOKENS");
      });

      it("compacts the value in a display unit", () => {
        const gold = display("GOLD", "100");
        const text = gold.ui({ unit: "gram", compact: true });

        expect(text).toBe("3.11K g");
      });

      it("refuses a bad compact option", () => {
        const tokens = display("TOKENS", 1_500n);
        const error = thrown(() => tokens.ui({ compact: { precision: 0 } }));

        expect(error).toMatchObject({ code: "INVALID_ARGUMENT" });
      });
    });
  });

  describe("unitLabel", () => {
    it("is the display symbol", () => {
      const usdc = display("USDC", "1");
      const label = usdc.unitLabel();

      expect(label).toBe("$");
    });

    it("is the plural form without a count", () => {
      const searches = display("SEARCHES", 1n);
      const label = searches.unitLabel();

      expect(label).toBe("searches");
    });

    it("agrees with a count of one", () => {
      const searches = display("SEARCHES", 1n);
      const label = searches.unitLabel({ count: 1 });

      expect(label).toBe("search");
    });

    it("agrees with a count written as a decimal one", () => {
      const searches = display("SEARCHES", 1n);
      const label = searches.unitLabel({ count: "1.0" });

      expect(label).toBe("search");
    });

    it("agrees with a count of many", () => {
      const searches = display("SEARCHES", 1n);
      const label = searches.unitLabel({ count: 2 });

      expect(label).toBe("searches");
    });

    it("agrees a translation with its count", () => {
      const searches = display("SEARCHES", 1n);
      const label = searches.unitLabel({ count: 1, locale: "de" });

      expect(label).toBe("Suche");
    });

    it("is a translated type label", () => {
      const gold = display("GOLD", "1");
      const label = gold.unitLabel({ locale: "de" });

      expect(label).toBe("Feinunze");
    });

    it("is a display unit's symbol", () => {
      const gold = display("GOLD", "1");
      const label = gold.unitLabel({ unit: "gram" });

      expect(label).toBe("g");
    });

    it("is a display unit's translation", () => {
      const gold = display("GOLD", "1");
      const label = gold.unitLabel({ unit: "gram", locale: "de" });

      expect(label).toBe("Gramm");
    });

    it("falls back from a unit without a symbol to the type's translation", () => {
      const gold = display("GOLD", "1");
      const label = gold.unitLabel({ unit: "oz_t", locale: "de" });

      expect(label).toBe("Feinunze");
    });

    it("refuses a count that is not a number", () => {
      const searches = display("SEARCHES", 1n);
      const error = thrown(() => searches.unitLabel({ count: "abc" }));

      expect(error).toMatchObject({ code: "INVALID_INPUT" });
    });
  });

  describe("displayFormat", () => {
    it("is the type's template", () => {
      const usd = display("USD", "1");
      const format = usd.displayFormat();

      expect(format).toBe("%u%n");
    });

    it("is the locale's template when it has one", () => {
      const eur = display("EUR", "1");
      const format = eur.displayFormat({ locale: "de" });

      expect(format).toBe("%n %u");
    });

    it("is a unit's position template", () => {
      const gold = display("GOLD", "1");
      const format = gold.displayFormat({ unit: "grain" });

      expect(format).toBe("%u%n");
    });

    it("falls back from a unit to the type's template", () => {
      const gold = display("GOLD", "1");
      const format = gold.displayFormat({ unit: "gram" });

      expect(format).toBe("%n %u");
    });

    it("is the locale's unit template when it has one", () => {
      const gold = display("GOLD", "1");
      const format = gold.displayFormat({ unit: "kg", locale: "de" });

      expect(format).toBe("%n %u");
    });
  });

  describe("toString", () => {
    it("rounds down to the display decimals", () => {
      const usdc = display("USDC", "1.239");
      const text = usdc.toString();

      expect(text).toBe("USDC|1.23");
    });

    it("rounds a negative value toward zero", () => {
      const usdc = display("USDC", "-1.239");
      const text = usdc.toString();

      expect(text).toBe("USDC|-1.23");
    });

    it("writes a negative value that rounds to zero without a sign", () => {
      const usdc = display("USDC", "-0.001");
      const text = usdc.toString();

      expect(text).toBe("USDC|0.00");
    });

    it("is never localized", () => {
      const usd = germanDisplay("USD", "1500.5");
      const text = usd.toString();

      expect(text).toBe("USD|1500.50");
    });
  });

  describe("formatted", () => {
    it("writes exactly the storage decimals", () => {
      const usdc = display("USDC", "1.5");
      const text = usdc.formatted();

      expect(text).toBe("1.500000");
    });

    it("writes no point without decimals", () => {
      const logs = display("LOGS", 5n);
      const text = logs.formatted();

      expect(text).toBe("5");
    });

    it("writes the sign", () => {
      const usdc = display("USDC", "-1.5");
      const text = usdc.formatted();

      expect(text).toBe("-1.500000");
    });
  });

  describe("inUnit", () => {
    it("is the exact value in the unit", () => {
      const gold = display("GOLD", "1");
      const grams = gold.inUnit("gram");

      expect(grams).toBe("31.1034768");
    });

    it("scales a fractional unit exactly", () => {
      const gold = display("GOLD", "2");
      const kilograms = gold.inUnit("kg");

      expect(kilograms).toBe("0.0622069536");
    });

    it("refuses an unknown unit", () => {
      const gold = display("GOLD", "1");
      const error = thrown(() => gold.inUnit("stone"));

      expect(error).toMatchObject({ code: "INVALID_DISPLAY_UNIT" });
    });
  });
});
