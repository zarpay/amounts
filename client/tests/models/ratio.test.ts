import { describe, expect, it } from "vitest";

import { Ratio } from "@/models/ratio.js";
import { thrown } from "@tests/helpers/fixtures.js";

describe("Ratio", () => {
  describe("of", () => {
    it("reduces the fraction", () => {
      const ratio = Ratio.of(10n, 4n);

      expect(ratio.toString()).toBe("5/2");
    });

    it("moves the sign to the numerator", () => {
      const ratio = Ratio.of(1n, -2n);

      expect(ratio.toString()).toBe("-1/2");
    });

    it("defaults the denominator to one", () => {
      const ratio = Ratio.of(7n);

      expect(ratio.denominator).toBe(1n);
    });

    it("writes zero as 0/1", () => {
      const ratio = Ratio.of(0n, 5n);

      expect(ratio.toString()).toBe("0/1");
    });

    it("refuses a zero denominator", () => {
      const error = thrown(() => Ratio.of(1n, 0n));

      expect(error).toMatchObject({ code: "ZERO_DIVISION" });
    });

    it("is frozen", () => {
      const ratio = Ratio.of(1n, 3n);

      expect(Object.isFrozen(ratio)).toBe(true);
    });
  });

  describe("powerOfTen", () => {
    it("is a whole power for a positive exponent", () => {
      const power = Ratio.powerOfTen(3);

      expect(power.toString()).toBe("1000/1");
    });

    it("is a fraction for a negative exponent", () => {
      const power = Ratio.powerOfTen(-2);

      expect(power.toString()).toBe("1/100");
    });
  });

  describe("parse", () => {
    it("reads a decimal string exactly", () => {
      const ratio = Ratio.parse("0.1");

      expect(ratio?.toString()).toBe("1/10");
    });

    it("reads a number through its string form", () => {
      const ratio = Ratio.parse(0.1);

      expect(ratio?.toString()).toBe("1/10");
    });

    it("reads a bigint as itself", () => {
      const ratio = Ratio.parse(12n);

      expect(ratio?.toString()).toBe("12/1");
    });

    it("reads an exponent", () => {
      const ratio = Ratio.parse("1.5e2");

      expect(ratio?.toString()).toBe("150/1");
    });

    it("returns null for text that is not a decimal", () => {
      const ratio = Ratio.parse("abc");

      expect(ratio).toBeNull();
    });

    it("returns null for NaN", () => {
      const ratio = Ratio.parse(Number.NaN);

      expect(ratio).toBeNull();
    });
  });

  describe("arithmetic", () => {
    const third = Ratio.of(1n, 3n);
    const half = Ratio.of(1n, 2n);

    it("adds", () => {
      const sum = third.add(half);

      expect(sum.toString()).toBe("5/6");
    });

    it("subtracts", () => {
      const difference = third.subtract(half);

      expect(difference.toString()).toBe("-1/6");
    });

    it("multiplies", () => {
      const product = third.multiply(half);

      expect(product.toString()).toBe("1/6");
    });

    it("divides", () => {
      const quotient = third.divide(half);

      expect(quotient.toString()).toBe("2/3");
    });

    it("refuses to divide by zero", () => {
      const zero = Ratio.of(0n);
      const error = thrown(() => third.divide(zero));

      expect(error).toMatchObject({ code: "ZERO_DIVISION" });
    });

    it("negates", () => {
      const negated = third.negate();

      expect(negated.toString()).toBe("-1/3");
    });

    it("takes the absolute value", () => {
      const negative = Ratio.of(-1n, 3n);
      const absolute = negative.abs();

      expect(absolute.toString()).toBe("1/3");
    });
  });

  describe("compare", () => {
    const third = Ratio.of(1n, 3n);
    const half = Ratio.of(1n, 2n);
    const twoQuarters = Ratio.of(2n, 4n);

    it("is -1 for a smaller value", () => {
      const order = third.compare(half);

      expect(order).toBe(-1);
    });

    it("is 1 for a larger value", () => {
      const order = half.compare(third);

      expect(order).toBe(1);
    });

    it("is 0 for an equal value", () => {
      const order = twoQuarters.compare(half);

      expect(order).toBe(0);
    });
  });

  describe("equals", () => {
    const third = Ratio.of(1n, 3n);
    const half = Ratio.of(1n, 2n);
    const twoQuarters = Ratio.of(2n, 4n);

    it("is true for equal values written differently", () => {
      const equal = twoQuarters.equals(half);

      expect(equal).toBe(true);
    });

    it("is false for different values", () => {
      const equal = third.equals(half);

      expect(equal).toBe(false);
    });
  });

  describe("isZero", () => {
    it("is true for zero", () => {
      const zero = Ratio.of(0n);

      expect(zero.isZero()).toBe(true);
    });

    it("is false otherwise", () => {
      const third = Ratio.of(1n, 3n);

      expect(third.isZero()).toBe(false);
    });
  });

  describe("integer parts", () => {
    const negativeSevenHalves = Ratio.of(-7n, 2n);

    it("truncates toward zero", () => {
      const truncated = negativeSevenHalves.truncate();

      expect(truncated).toBe(-3n);
    });

    it("floors toward negative infinity", () => {
      const floored = negativeSevenHalves.floor();

      expect(floored).toBe(-4n);
    });

    it("ceils toward positive infinity", () => {
      const ceiled = negativeSevenHalves.ceil();

      expect(ceiled).toBe(-3n);
    });

    it("floors an integer to itself", () => {
      const negativeFour = Ratio.of(-4n);
      const floored = negativeFour.floor();

      expect(floored).toBe(-4n);
    });

    it("ceils a positive fraction up", () => {
      const sevenHalves = Ratio.of(7n, 2n);
      const ceiled = sevenHalves.ceil();

      expect(ceiled).toBe(4n);
    });
  });

  describe("round", () => {
    const value = Ratio.parse("1.239")!;

    it("rounds down by default", () => {
      const rounded = value.round(2);

      expect(rounded.toString()).toBe("123/100");
    });

    it("rounds up with ceil", () => {
      const rounded = value.round(2, "ceil");

      expect(rounded.toString()).toBe("31/25");
    });

    it("rounds a negative value down, away from zero", () => {
      const negative = Ratio.parse("-1.234")!;
      const rounded = negative.round(2);

      expect(rounded.toString()).toBe("-31/25");
    });

    it("rounds to tens with negative places", () => {
      const large = Ratio.of(123n);
      const rounded = large.round(-1);

      expect(rounded.toString()).toBe("120/1");
    });
  });

  describe("toFixed", () => {
    const tenThirds = Ratio.of(10n, 3n);

    it("writes exactly the places asked for, rounded down", () => {
      const fixed = tenThirds.toFixed(4);

      expect(fixed).toBe("3.3333");
    });

    it("rounds up with ceil", () => {
      const fixed = tenThirds.toFixed(4, "ceil");

      expect(fixed).toBe("3.3334");
    });

    it("writes no point for zero places", () => {
      const fixed = tenThirds.toFixed(0);

      expect(fixed).toBe("3");
    });

    it("refuses negative places", () => {
      const error = thrown(() => tenThirds.toFixed(-1));

      expect(error).toMatchObject({ code: "INVALID_ARGUMENT" });
    });
  });

  describe("toDecimal", () => {
    it("writes a terminating value without trailing zeros", () => {
      const threeTwentieths = Ratio.of(3n, 20n);
      const decimal = threeTwentieths.toDecimal();

      expect(decimal).toBe("0.15");
    });

    it("writes an integer with a point, as BigDecimal#to_s('F')", () => {
      const one = Ratio.of(1n);
      const decimal = one.toDecimal();

      expect(decimal).toBe("1.0");
    });

    it("writes the sign", () => {
      const negativeQuarter = Ratio.of(-1n, 4n);
      const decimal = negativeQuarter.toDecimal();

      expect(decimal).toBe("-0.25");
    });

    it("refuses a repeating value", () => {
      const third = Ratio.of(1n, 3n);
      const error = thrown(() => third.toDecimal());

      expect(error).toMatchObject({ code: "INVALID_ARGUMENT" });
    });
  });
});
