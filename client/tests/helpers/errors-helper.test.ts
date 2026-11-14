import { describe, expect, it } from "vitest";

import { AmountError, errors } from "@/helpers/errors-helper.js";

describe("AmountError", () => {
  it("is an Error", () => {
    const error = new AmountError("INVALID_INPUT", "bad");

    expect(error).toBeInstanceOf(Error);
  });

  it("carries its code", () => {
    const error = new AmountError("INVALID_INPUT", "bad");

    expect(error.code).toBe("INVALID_INPUT");
  });

  it("is named AmountError", () => {
    const error = new AmountError("INVALID_INPUT", "bad");

    expect(error.name).toBe("AmountError");
  });
});

describe("errors", () => {
  it("words a type mismatch as the gem does", () => {
    const error = errors.typeMismatch("USDC", "GOLD");

    expect(error.message).toBe("type mismatch: USDC vs GOLD");
  });

  it("codes a non-scalar as a type mismatch", () => {
    const error = errors.notScalar("Amount");

    expect(error.code).toBe("TYPE_MISMATCH");
  });

  it("quotes a string input it cannot parse", () => {
    const error = errors.cannotParse("abc", "USDC");

    expect(error.message).toBe('cannot parse "abc" as USDC');
  });

  it("names the reason a typed value is rejected", () => {
    const error = errors.cannotParseUi("1.2.3", "USD", "a decimal separator is used twice");

    expect(error.message).toBe('cannot parse "1.2.3" as USD: a decimal separator is used twice');
  });

  it("words an unknown type as the gem does", () => {
    const error = errors.unknownType("DOGE");

    expect(error.message).toBe("DOGE is not registered");
  });

  it("words a missing default rate as the gem does", () => {
    const error = errors.noDefaultRate("USDC", "GOLD");

    expect(error.message).toBe("no default rate for USDC -> GOLD; pass rate: explicitly");
  });

  it("codes an unknown display unit", () => {
    const error = errors.unknownDisplayUnit("stone", "GOLD");

    expect(error.code).toBe("INVALID_DISPLAY_UNIT");
  });

  it("codes a type without display units as an invalid display unit", () => {
    const error = errors.noDisplayUnits("USD");

    expect(error.code).toBe("INVALID_DISPLAY_UNIT");
  });

  it("codes division by zero", () => {
    const error = errors.zeroDivision();

    expect(error.code).toBe("ZERO_DIVISION");
  });

  it("words an incomparable operand as Ruby's Comparable does", () => {
    const error = errors.notComparable("GOLD");

    expect(error.message).toBe("comparison of Amount with GOLD failed");
  });

  it("describes a bad compact option", () => {
    const error = errors.invalidCompactOption("yes");

    expect(error.message).toBe('compact: must be true, false or { precision: Integer }, got "yes"');
  });

  it("describes a bad compact precision", () => {
    const error = errors.invalidCompactPrecision(0);

    expect(error.message).toBe("compact: precision must be a positive Integer, got 0");
  });

  it("names the locale the manifest lacks", () => {
    const error = errors.unknownLocale("ja");

    expect(error.message).toBe('the manifest has no locale "ja"');
  });

  it("names the malformed manifest path", () => {
    const error = errors.invalidManifest("types.USDC.decimals", "a non-negative integer");

    expect(error.message).toBe(
      "invalid manifest: types.USDC.decimals must be a non-negative integer",
    );
  });
});
