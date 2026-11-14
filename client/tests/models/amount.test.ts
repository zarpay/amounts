import type { Amount } from "@/models/amount.js";

import { describe, expect, it } from "vitest";

import { Ratio } from "@/models/ratio.js";
import { testAmounts, thrown } from "@tests/helpers/fixtures.js";

const amounts = testAmounts();

const oneUsdc = amounts.of("USDC", "1");
const twoUsdc = amounts.of("USDC", "2");
const threeUsdc = amounts.of("USDC", "3");
const tenUsdc = amounts.of("USDC", "10");
const zeroUsdc = amounts.of("USDC", "0");
const quarterUsdc = amounts.of("USDC", "0.25");
const oneAndAQuarterUsdc = amounts.of("USDC", "1.25");
const oneAndAHalfUsdc = amounts.of("USDC", "1.5");
const unroundedUsdc = amounts.of("USDC", "1.239");
const minusOneUsdc = amounts.of("USDC", "-1");
const minusOneAndAHalfUsdc = amounts.of("USDC", "-1.5");
const minusQuarterUsdc = amounts.of("USDC", "-0.25");
const oneUsd = amounts.of("USD", "1");
const twoUsd = amounts.of("USD", "2");
const fiveUsd = amounts.of("USD", "5");
const quarterUsd = amounts.of("USD", "0.25");
const oneGold = amounts.of("GOLD", "1");
const tenLogs = amounts.of("LOGS", 10n);
const minusTenLogs = amounts.of("LOGS", -10n);
const zeroLogs = amounts.of("LOGS", 0n);
const fiveLogs = amounts.of("LOGS", 5n);
const minusFiveLogs = amounts.of("LOGS", -5n);
const hugeEth = amounts.of("ETH", 10n ** 40n);

/** The atomic values of a split or allocation, parts then remainder. */
function atomics([parts, remainder]: [Amount[], Amount]): [bigint[], bigint] {
  const partAtomics = parts.map((part) => part.atomic);

  return [partAtomics, remainder.atomic];
}

describe("Amount", () => {
  describe("identity", () => {
    it("holds its symbol", () => {
      expect(oneAndAHalfUsdc.symbol).toBe("USDC");
    });

    it("holds its type's decimals", () => {
      expect(oneAndAHalfUsdc.decimals).toBe(6);
    });

    it("holds its registry entry", () => {
      expect(oneAndAHalfUsdc.registryEntry.displaySymbol).toBe("$");
    });

    it("is frozen", () => {
      const frozen = Object.isFrozen(oneAndAHalfUsdc);

      expect(frozen).toBe(true);
    });
  });

  describe("decimal", () => {
    it("is the exact whole-unit value", () => {
      expect(oneAndAHalfUsdc.decimal).toBe("1.5");
    });

    it("writes a whole value with a point", () => {
      expect(oneUsdc.decimal).toBe("1.0");
    });

    it("writes the sign", () => {
      expect(minusQuarterUsdc.decimal).toBe("-0.25");
    });

    it("writes a type without decimals with a point", () => {
      expect(minusFiveLogs.decimal).toBe("-5.0");
    });
  });

  describe("toRatio", () => {
    it("is the whole-unit value as a fraction", () => {
      const ratio = oneAndAHalfUsdc.toRatio();

      expect(ratio.toString()).toBe("3/2");
    });
  });

  describe("add", () => {
    it("adds the same type", () => {
      const sum = oneAndAHalfUsdc.add(quarterUsdc);

      expect(sum.atomic).toBe(1750000n);
    });

    it("converts another type through its default rate", () => {
      const sum = tenUsdc.add(fiveUsd);

      expect(sum.atomic).toBe(15000000n);
    });

    it("keeps the receiver's type", () => {
      const sum = fiveUsd.add(tenUsdc);

      expect(sum.symbol).toBe("USD");
    });

    it("converts into the receiver's atomic unit", () => {
      const sum = fiveUsd.add(tenUsdc);

      expect(sum.atomic).toBe(1500n);
    });

    it("refuses a type without a default rate", () => {
      const error = thrown(() => oneUsdc.add(oneGold));

      expect(error).toMatchObject({
        code: "TYPE_MISMATCH",
        message: "type mismatch: USDC vs GOLD",
      });
    });

    it("refuses something that is not an amount", () => {
      const notAnAmount = 5 as unknown as Amount;
      const error = thrown(() => oneUsdc.add(notAnAmount));

      expect(error).toMatchObject({ message: "type mismatch: USDC vs number" });
    });
  });

  describe("subtract", () => {
    it("subtracts the same type", () => {
      const difference = oneUsdc.subtract(quarterUsdc);

      expect(difference.atomic).toBe(750000n);
    });

    it("converts another type through its default rate", () => {
      const difference = oneUsdc.subtract(quarterUsd);

      expect(difference.atomic).toBe(750000n);
    });

    it("refuses a type without a default rate", () => {
      const error = thrown(() => oneUsdc.subtract(oneGold));

      expect(error).toMatchObject({ code: "TYPE_MISMATCH" });
    });
  });

  describe("multiply", () => {
    it("multiplies by an integer", () => {
      const product = oneAndAQuarterUsdc.multiply(2);

      expect(product.atomic).toBe(2500000n);
    });

    it("multiplies by a number through its string form", () => {
      const product = oneAndAHalfUsdc.multiply(0.1);

      expect(product.atomic).toBe(150000n);
    });

    it("multiplies by a decimal string exactly", () => {
      const product = oneUsdc.multiply("0.3333333");

      expect(product.atomic).toBe(333333n);
    });

    it("truncates a negative product toward zero", () => {
      const product = minusOneUsdc.multiply("0.3333333");

      expect(product.atomic).toBe(-333333n);
    });

    it("multiplies by a bigint", () => {
      const product = oneUsdc.multiply(3n);

      expect(product.atomic).toBe(3000000n);
    });

    it("refuses an amount", () => {
      const operand = oneUsdc as unknown as number;
      const error = thrown(() => oneUsdc.multiply(operand));

      expect(error).toMatchObject({ message: "expected scalar, got Amount" });
    });

    it("refuses an unreadable string", () => {
      const error = thrown(() => oneUsdc.multiply("two"));

      expect(error).toMatchObject({ code: "INVALID_INPUT" });
    });
  });

  describe("divide", () => {
    it("truncates a scalar quotient toward zero", () => {
      const quotient = minusOneUsdc.divide(3);

      expect(quotient.atomic).toBe(-333333n);
    });

    it("divides a value past 2^53 exactly", () => {
      const quotient = hugeEth.divide(7);

      expect(quotient.atomic).toBe(1428571428571428571428571428571428571428n);
    });

    it("refuses division by zero", () => {
      const error = thrown(() => oneUsdc.divide(0));

      expect(error).toMatchObject({ code: "ZERO_DIVISION" });
    });

    it("returns the exact ratio of two amounts", () => {
      const ratio = tenUsdc.divide(threeUsdc);

      expect(ratio.toString()).toBe("10/3");
    });

    it("returns a Ratio for two amounts", () => {
      const ratio = tenUsdc.divide(threeUsdc);

      expect(ratio).toBeInstanceOf(Ratio);
    });

    it("refuses the ratio of two types", () => {
      const error = thrown(() => oneUsdc.divide(oneUsd));

      expect(error).toMatchObject({ message: "type mismatch: USDC vs USD" });
    });

    it("refuses a ratio to zero", () => {
      const error = thrown(() => oneUsdc.divide(zeroUsdc));

      expect(error).toMatchObject({ code: "ZERO_DIVISION" });
    });
  });

  describe("abs", () => {
    it("drops the sign", () => {
      const absolute = minusOneUsdc.abs();

      expect(absolute.atomic).toBe(1000000n);
    });
  });

  describe("negate", () => {
    it("flips the sign", () => {
      const negated = oneUsdc.negate();

      expect(negated.atomic).toBe(-1000000n);
    });
  });

  describe("sameType", () => {
    it("is true for the same symbol", () => {
      const same = oneUsdc.sameType(twoUsdc);

      expect(same).toBe(true);
    });

    it("is false for another symbol", () => {
      const same = oneUsdc.sameType(oneUsd);

      expect(same).toBe(false);
    });

    it("is false for something that is not an amount", () => {
      const same = oneUsdc.sameType("USDC");

      expect(same).toBe(false);
    });
  });

  describe("compare", () => {
    it("is -1 for a smaller amount, converting through a default rate", () => {
      const order = oneUsdc.compare(twoUsd);

      expect(order).toBe(-1);
    });

    it("is 1 for a larger amount, converting through a default rate", () => {
      const order = twoUsd.compare(oneUsdc);

      expect(order).toBe(1);
    });

    it("is 0 for an equal amount", () => {
      const order = oneUsdc.compare(oneUsdc);

      expect(order).toBe(0);
    });

    it("is null without a default rate", () => {
      const order = oneUsdc.compare(oneGold);

      expect(order).toBeNull();
    });

    it("is null for something that is not an amount", () => {
      const order = oneUsdc.compare(1);

      expect(order).toBeNull();
    });
  });

  describe("equals", () => {
    it("is true for the same type and value", () => {
      const other = amounts.of("USDC", "1.5");
      const equal = oneAndAHalfUsdc.equals(other);

      expect(equal).toBe(true);
    });

    it("is false across types, even at a rate of one", () => {
      const equal = oneUsdc.equals(oneUsd);

      expect(equal).toBe(false);
    });

    it("is false for another value", () => {
      const equal = oneUsdc.equals(twoUsdc);

      expect(equal).toBe(false);
    });
  });

  describe("ordering", () => {
    it("is less than a larger amount", () => {
      const less = oneUsdc.lessThan(twoUsd);

      expect(less).toBe(true);
    });

    it("is less than or equal to an equal amount", () => {
      const lessOrEqual = oneUsdc.lessThanOrEqual(oneUsdc);

      expect(lessOrEqual).toBe(true);
    });

    it("is greater than a smaller amount", () => {
      const greater = twoUsdc.greaterThan(oneUsdc);

      expect(greater).toBe(true);
    });

    it("is greater than or equal to an equal amount", () => {
      const greaterOrEqual = oneUsdc.greaterThanOrEqual(oneUsdc);

      expect(greaterOrEqual).toBe(true);
    });

    it("refuses an amount it can't compare, as Ruby's Comparable", () => {
      const error = thrown(() => oneUsdc.lessThan(oneGold));

      expect(error).toMatchObject({
        code: "NOT_COMPARABLE",
        message: "comparison of Amount with Amount failed",
      });
    });
  });

  describe("sign predicates", () => {
    it("is zero for zero", () => {
      const zero = zeroUsdc.isZero();

      expect(zero).toBe(true);
    });

    it("is positive above zero", () => {
      const positive = oneUsdc.isPositive();

      expect(positive).toBe(true);
    });

    it("is negative below zero", () => {
      const negative = minusOneUsdc.isNegative();

      expect(negative).toBe(true);
    });

    it("is not positive at zero", () => {
      const positive = zeroUsdc.isPositive();

      expect(positive).toBe(false);
    });
  });

  describe("to", () => {
    it("converts through the default rate, truncating", () => {
      const sol = oneUsdc.to("SOL");

      expect(sol.atomic).toBe(6666666n);
    });

    it("truncates a negative conversion toward zero", () => {
      const sol = minusOneUsdc.to("SOL");

      expect(sol.atomic).toBe(-6666666n);
    });

    it("converts through a Rational rate as the gem does", () => {
      const eur = threeUsdc.to("EUR");

      expect(eur.atomic).toBe(99n);
    });

    it("converts through an explicit rate", () => {
      const converted = oneUsdc.to("GOLD", { rate: "0.00042" });

      expect(converted.atomic).toBe(42000n);
    });

    it("returns the target type", () => {
      const converted = oneUsdc.to("GOLD", { rate: "0.00042" });

      expect(converted.symbol).toBe("GOLD");
    });

    it("copies an amount into its own type", () => {
      const same = oneUsdc.to("USDC");

      expect(same.atomic).toBe(1000000n);
    });

    it("refuses a conversion without a rate", () => {
      const error = thrown(() => oneUsdc.to("GOLD"));

      expect(error).toMatchObject({
        code: "NO_DEFAULT_RATE",
        message: "no default rate for USDC -> GOLD; pass rate: explicitly",
      });
    });

    it("refuses an unknown target with an explicit rate", () => {
      const error = thrown(() => oneUsdc.to("DOGE", { rate: "1" }));

      expect(error).toMatchObject({ code: "UNKNOWN_TYPE" });
    });

    it("looks for a rate before the target, as the gem does", () => {
      const error = thrown(() => oneUsdc.to("DOGE"));

      expect(error).toMatchObject({ code: "NO_DEFAULT_RATE" });
    });

    it("refuses an unreadable rate", () => {
      const error = thrown(() => oneUsdc.to("GOLD", { rate: "high" }));

      expect(error).toMatchObject({ code: "INVALID_INPUT" });
    });
  });

  describe("split", () => {
    it("splits into equal parts and a remainder", () => {
      const split = tenLogs.split(3);
      const values = atomics(split);

      expect(values).toEqual([[3n, 3n, 3n], 1n]);
    });

    it("keeps the sign on every part and the remainder", () => {
      const split = minusTenLogs.split(3);
      const values = atomics(split);

      expect(values).toEqual([[-3n, -3n, -3n], -1n]);
    });

    it("splits zero into zeros", () => {
      const split = zeroLogs.split(3);
      const values = atomics(split);

      expect(values).toEqual([[0n, 0n, 0n], 0n]);
    });

    it("refuses zero parts", () => {
      const error = thrown(() => tenLogs.split(0));

      expect(error).toMatchObject({ message: "n must be positive" });
    });

    it("refuses a fractional count", () => {
      const error = thrown(() => tenLogs.split(1.5));

      expect(error).toMatchObject({ code: "INVALID_ARGUMENT" });
    });
  });

  describe("allocate", () => {
    it("allocates by weight with a remainder", () => {
      const allocation = tenLogs.allocate([1, 1, 2]);
      const values = atomics(allocation);

      expect(values).toEqual([[2n, 2n, 5n], 1n]);
    });

    it("keeps the sign on every part and the remainder", () => {
      const allocation = minusTenLogs.allocate([1, 1, 2]);
      const values = atomics(allocation);

      expect(values).toEqual([[-2n, -2n, -5n], -1n]);
    });

    it("gives a zero weight nothing", () => {
      const allocation = tenLogs.allocate([0, 3]);
      const values = atomics(allocation);

      expect(values).toEqual([[0n, 10n], 0n]);
    });

    it("accepts bigint weights", () => {
      const allocation = tenLogs.allocate([1n, 1n]);
      const values = atomics(allocation);

      expect(values).toEqual([[5n, 5n], 0n]);
    });

    it("refuses no weights", () => {
      const error = thrown(() => tenLogs.allocate([]));

      expect(error).toMatchObject({ message: "weights must be non-empty" });
    });

    it("refuses a negative weight", () => {
      const error = thrown(() => tenLogs.allocate([-1, 2]));

      expect(error).toMatchObject({ message: "weights must be non-negative integers" });
    });

    it("refuses a fractional weight", () => {
      const error = thrown(() => tenLogs.allocate([0.5, 2]));

      expect(error).toMatchObject({ message: "weights must be non-negative integers" });
    });

    it("refuses weights summing to zero", () => {
      const error = thrown(() => tenLogs.allocate([0, 0]));

      expect(error).toMatchObject({ message: "weights must sum to positive value" });
    });
  });

  describe("toHash", () => {
    it("is the versioned payload with a string atomic", () => {
      const hash = oneAndAHalfUsdc.toHash();

      expect(hash).toEqual({ v: 1, atomic: "1500000", symbol: "USDC" });
    });
  });

  describe("toJSON", () => {
    it("is the exact compact string", () => {
      const json = oneAndAHalfUsdc.toJSON();

      expect(json).toBe("USDC|1.500000");
    });

    it("writes the sign before the number", () => {
      const json = minusOneAndAHalfUsdc.toJSON();

      expect(json).toBe("USDC|-1.500000");
    });

    it("writes no point without decimals", () => {
      const json = fiveLogs.toJSON();

      expect(json).toBe("LOGS|5");
    });

    it("is what JSON.stringify writes", () => {
      const payload = { total: oneAndAHalfUsdc };
      const json = JSON.stringify(payload);

      expect(json).toBe('{"total":"USDC|1.500000"}');
    });
  });

  describe("display", () => {
    it("formats for people", () => {
      const text = oneAndAHalfUsdc.ui();

      expect(text).toBe("$1.50");
    });

    it("writes the display-rounded compact string", () => {
      const text = unroundedUsdc.toString();

      expect(text).toBe("USDC|1.23");
    });

    it("writes the exact number", () => {
      const text = oneAndAHalfUsdc.formatted();

      expect(text).toBe("1.500000");
    });

    it("reads the unit label", () => {
      const label = oneGold.unitLabel({ unit: "gram" });

      expect(label).toBe("g");
    });

    it("reads the display template", () => {
      const format = oneUsd.displayFormat();

      expect(format).toBe("%u%n");
    });

    it("converts to a display unit exactly", () => {
      const grams = oneGold.inUnit("gram");

      expect(grams).toBe("31.1034768");
    });
  });
});
