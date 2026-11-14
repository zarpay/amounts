import { describe, expect, it } from "vitest";

import {
  decimalText,
  formatScaled,
  isDecimalInput,
  parseDecimal,
} from "@/helpers/decimal-helper.js";

describe("parseDecimal", () => {
  it("reads a plain decimal", () => {
    const decimal = parseDecimal("1.5");

    expect(decimal).toEqual({ coefficient: 15n, scale: 1 });
  });

  it("reads an integer", () => {
    const decimal = parseDecimal("42");

    expect(decimal).toEqual({ coefficient: 42n, scale: 0 });
  });

  it("reads a negative sign", () => {
    const decimal = parseDecimal("-1.5");

    expect(decimal).toEqual({ coefficient: -15n, scale: 1 });
  });

  it("reads a plus sign", () => {
    const decimal = parseDecimal("+1");

    expect(decimal).toEqual({ coefficient: 1n, scale: 0 });
  });

  it("ignores surrounding whitespace", () => {
    const decimal = parseDecimal(" 1.5 ");

    expect(decimal).toEqual({ coefficient: 15n, scale: 1 });
  });

  it("drops underscores between digits", () => {
    const decimal = parseDecimal("1_000");

    expect(decimal).toEqual({ coefficient: 1000n, scale: 0 });
  });

  it("reads a bare leading point", () => {
    const decimal = parseDecimal(".5");

    expect(decimal).toEqual({ coefficient: 5n, scale: 1 });
  });

  it("reads a bare trailing point", () => {
    const decimal = parseDecimal("5.");

    expect(decimal).toEqual({ coefficient: 5n, scale: 0 });
  });

  it("reads a positive exponent", () => {
    const decimal = parseDecimal("1.5e2");

    expect(decimal).toEqual({ coefficient: 15n, scale: -1 });
  });

  it("reads a negative exponent", () => {
    const decimal = parseDecimal("1e-7");

    expect(decimal).toEqual({ coefficient: 1n, scale: 7 });
  });

  it("reads JavaScript's exponent form", () => {
    const decimal = parseDecimal("1e+21");

    expect(decimal).toEqual({ coefficient: 1n, scale: -21 });
  });

  it("rejects letters", () => {
    const decimal = parseDecimal("abc");

    expect(decimal).toBeNull();
  });

  it("rejects a comma", () => {
    const decimal = parseDecimal("1,5");

    expect(decimal).toBeNull();
  });

  it("rejects hexadecimal", () => {
    const decimal = parseDecimal("0x10");

    expect(decimal).toBeNull();
  });

  it("rejects blank text", () => {
    const decimal = parseDecimal("  ");

    expect(decimal).toBeNull();
  });

  it("rejects a lone point", () => {
    const decimal = parseDecimal(".");

    expect(decimal).toBeNull();
  });

  it("rejects doubled underscores", () => {
    const decimal = parseDecimal("1__0");

    expect(decimal).toBeNull();
  });

  it("rejects a leading underscore", () => {
    const decimal = parseDecimal("_1");

    expect(decimal).toBeNull();
  });

  it("rejects an exponent past the limit", () => {
    const decimal = parseDecimal("1e10001");

    expect(decimal).toBeNull();
  });
});

describe("decimalText", () => {
  it("passes a string through", () => {
    const text = decimalText("1.5");

    expect(text).toBe("1.5");
  });

  it("writes a bigint as its digits", () => {
    const text = decimalText(15n);

    expect(text).toBe("15");
  });

  it("writes a number through its string form", () => {
    const text = decimalText(0.1);

    expect(text).toBe("0.1");
  });

  it("refuses NaN", () => {
    const text = decimalText(Number.NaN);

    expect(text).toBeNull();
  });

  it("refuses Infinity", () => {
    const text = decimalText(Number.POSITIVE_INFINITY);

    expect(text).toBeNull();
  });

  it("refuses another type", () => {
    const text = decimalText({});

    expect(text).toBeNull();
  });
});

describe("isDecimalInput", () => {
  it("accepts a string", () => {
    const accepted = isDecimalInput("1");

    expect(accepted).toBe(true);
  });

  it("accepts a bigint", () => {
    const accepted = isDecimalInput(1n);

    expect(accepted).toBe(true);
  });

  it("accepts a number", () => {
    const accepted = isDecimalInput(1);

    expect(accepted).toBe(true);
  });

  it("refuses an object", () => {
    const accepted = isDecimalInput({});

    expect(accepted).toBe(false);
  });
});

describe("formatScaled", () => {
  it("places the point", () => {
    const text = formatScaled(150n, 2);

    expect(text).toBe("1.50");
  });

  it("pads a value below one", () => {
    const text = formatScaled(5n, 3);

    expect(text).toBe("0.005");
  });

  it("writes the sign", () => {
    const text = formatScaled(-150n, 2);

    expect(text).toBe("-1.50");
  });

  it("writes no point for zero places", () => {
    const text = formatScaled(42n, 0);

    expect(text).toBe("42");
  });

  it("writes every digit of a value past 2^53", () => {
    const text = formatScaled(123456789012345678901234567890n, 18);

    expect(text).toBe("123456789012.345678901234567890");
  });
});
