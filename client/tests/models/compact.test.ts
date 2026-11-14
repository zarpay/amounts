import { describe, expect, it } from "vitest";

import { Compact } from "@/models/compact.js";
import { Ratio } from "@/models/ratio.js";
import { testAmounts, thrown } from "@tests/helpers/fixtures.js";

const registry = testAmounts().registry;
const de = registry.locale("de");

function value(text: string): Ratio {
  return Ratio.parse(text)!;
}

describe("Compact", () => {
  describe("precision", () => {
    it("is off for undefined", () => {
      const precision = Compact.precision(undefined);

      expect(precision).toBeNull();
    });

    it("is off for false", () => {
      const precision = Compact.precision(false);

      expect(precision).toBeNull();
    });

    it("keeps 3 digits for true", () => {
      const precision = Compact.precision(true);

      expect(precision).toBe(3);
    });

    it("keeps 3 digits for an empty object", () => {
      const precision = Compact.precision({});

      expect(precision).toBe(3);
    });

    it("reads the precision", () => {
      const precision = Compact.precision({ precision: 2 });

      expect(precision).toBe(2);
    });

    it("refuses another kind of option", () => {
      const option = "yes" as unknown as boolean;
      const error = thrown(() => Compact.precision(option));

      expect(error).toMatchObject({
        message: 'compact: must be true, false or { precision: Integer }, got "yes"',
      });
    });

    it("refuses a precision of zero", () => {
      const error = thrown(() => Compact.precision({ precision: 0 }));

      expect(error).toMatchObject({
        message: "compact: precision must be a positive Integer, got 0",
      });
    });

    it("refuses an unknown key", () => {
      const option = { digits: 2 } as unknown as { precision: number };
      const error = thrown(() => Compact.precision(option));

      expect(error).toMatchObject({ message: "unknown compact: option(s) digits" });
    });
  });

  describe("applies", () => {
    it("is true from one thousand", () => {
      const thousand = value("1000");
      const applies = Compact.applies(thousand);

      expect(applies).toBe(true);
    });

    it("is false below one thousand", () => {
      const justBelow = value("999.99");
      const applies = Compact.applies(justBelow);

      expect(applies).toBe(false);
    });

    it("is true for a large negative number", () => {
      const negative = value("-1500");
      const applies = Compact.applies(negative);

      expect(applies).toBe(true);
    });
  });

  describe("format", () => {
    const thousandFiveHundred = value("1500");
    const oneMillion = value("1000000");
    const millionAndAHalf = value("1500000");
    const fiftyMillion = value("50000000");
    const justUnderTwoMillion = value("1999999");
    const justUnderAMillion = value("999999");
    const severalDigits = value("1234567");
    const sixDigits = value("123456");
    const negative = value("-1500000");
    const minusJustUnderTwoMillion = value("-1999999");
    const minusJustUnderAMillion = value("-999999");
    const pastDecillions = value("1.5e36");
    const twoAndAHalfMillion = value("2500000");
    const billionAndAHalf = value("1500000000");

    it("divides by the largest scale reached", () => {
      const compacted = Compact.format(millionAndAHalf, 3, "floor", null);

      expect(compacted).toBe("1.5M");
    });

    it("trims a whole mantissa", () => {
      const compacted = Compact.format(fiftyMillion, 3, "floor", null);

      expect(compacted).toBe("50M");
    });

    it("rounds down to the significant digits", () => {
      const compacted = Compact.format(justUnderTwoMillion, 3, "floor", null);

      expect(compacted).toBe("1.99M");
    });

    it("carries a rounded-up mantissa to the next scale", () => {
      const compacted = Compact.format(justUnderAMillion, 3, "ceil", null);

      expect(compacted).toBe("1M");
    });

    it("keeps fewer significant digits", () => {
      const compacted = Compact.format(severalDigits, 2, "floor", null);

      expect(compacted).toBe("1.2M");
    });

    it("rounds past the decimal point for a low precision", () => {
      const compacted = Compact.format(sixDigits, 1, "floor", null);

      expect(compacted).toBe("100K");
    });

    it("keeps the sign", () => {
      const compacted = Compact.format(negative, 3, "floor", null);

      expect(compacted).toBe("-1.5M");
    });

    it("rounds a negative value toward zero", () => {
      const compacted = Compact.format(minusJustUnderTwoMillion, 3, "floor", null);

      expect(compacted).toBe("-1.99M");
    });

    it("rounds a negative value away from zero with ceil", () => {
      const compacted = Compact.format(minusJustUnderTwoMillion, 3, "ceil", null);

      expect(compacted).toBe("-2M");
    });

    it("keeps a negative value in its scale when rounding toward zero", () => {
      const compacted = Compact.format(minusJustUnderAMillion, 3, "floor", null);

      expect(compacted).toBe("-999K");
    });

    it("carries a negative value to the next scale with ceil", () => {
      const compacted = Compact.format(minusJustUnderAMillion, 3, "ceil", null);

      expect(compacted).toBe("-1M");
    });

    it("stays in decillions past them", () => {
      const compacted = Compact.format(pastDecillions, 3, "floor", null);

      expect(compacted).toBe("1500Dc");
    });

    it("uses the locale's word and format", () => {
      const compacted = Compact.format(thousandFiveHundred, 3, "floor", de);

      expect(compacted).toBe("1,5 Tsd.");
    });

    it("pluralizes the locale's word with the mantissa", () => {
      const compacted = Compact.format(twoAndAHalfMillion, 3, "floor", de);

      expect(compacted).toBe("2,5 Millionen");
    });

    it("picks the singular word for a mantissa of one", () => {
      const compacted = Compact.format(oneMillion, 3, "floor", de);

      expect(compacted).toBe("1 Million");
    });

    it("falls back to the short form for an untranslated scale", () => {
      const compacted = Compact.format(billionAndAHalf, 3, "floor", de);

      expect(compacted).toBe("1,5B");
    });
  });
});
