import { describe, expect, it } from "vitest";

import {
  readArray,
  readBoolean,
  readCount,
  readDecimal,
  readDisplaySymbol,
  readLabel,
  readNullable,
  readRecord,
  readString,
  readTemplate,
} from "@/helpers/manifest-helper.js";
import { thrown } from "@tests/helpers/fixtures.js";

describe("readRecord", () => {
  it("returns an object", () => {
    const record = readRecord({ a: 1 }, "x");

    expect(record).toEqual({ a: 1 });
  });

  it("refuses an array", () => {
    const error = thrown(() => readRecord([], "x"));

    expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
  });

  it("refuses null", () => {
    const error = thrown(() => readRecord(null, "x"));

    expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
  });

  it("names the path it refused", () => {
    const error = thrown(() => readRecord(1, "types.USDC"));

    expect(error).toMatchObject({ message: "invalid manifest: types.USDC must be an object" });
  });
});

describe("readArray", () => {
  it("returns an array", () => {
    const array = readArray([1], "x");

    expect(array).toEqual([1]);
  });

  it("refuses an object", () => {
    const error = thrown(() => readArray({}, "x"));

    expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
  });
});

describe("readCount", () => {
  it("returns a non-negative integer", () => {
    const count = readCount(6, "x");

    expect(count).toBe(6);
  });

  it("refuses a negative integer", () => {
    const error = thrown(() => readCount(-1, "x"));

    expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
  });

  it("refuses a fraction", () => {
    const error = thrown(() => readCount(1.5, "x"));

    expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
  });

  it("refuses a numeric string", () => {
    const error = thrown(() => readCount("6", "x"));

    expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
  });
});

describe("readString", () => {
  it("returns a string", () => {
    const text = readString("USDC", "x");

    expect(text).toBe("USDC");
  });

  it("refuses a missing value", () => {
    const error = thrown(() => readString(undefined, "x"));

    expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
  });
});

describe("readBoolean", () => {
  it("returns a boolean", () => {
    const flag = readBoolean(false, "x");

    expect(flag).toBe(false);
  });

  it("refuses a truthy non-boolean", () => {
    const error = thrown(() => readBoolean(1, "x"));

    expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
  });
});

describe("readDecimal", () => {
  it("returns a decimal string", () => {
    const decimal = readDecimal("31.1034768", "x");

    expect(decimal).toBe("31.1034768");
  });

  it("refuses a number", () => {
    const error = thrown(() => readDecimal(1, "x"));

    expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
  });

  it("refuses text that is not a decimal", () => {
    const error = thrown(() => readDecimal("one", "x"));

    expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
  });
});

describe("readTemplate", () => {
  it("returns a template", () => {
    const template = readTemplate("%u%n", "x");

    expect(template).toBe("%u%n");
  });

  it("refuses a template without the number", () => {
    const error = thrown(() => readTemplate("%u", "x"));

    expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
  });
});

describe("readLabel", () => {
  it("returns a string label", () => {
    const label = readLabel("$", "x");

    expect(label).toBe("$");
  });

  it("returns plural forms", () => {
    const label = readLabel({ one: "search", other: "searches" }, "x");

    expect(label).toEqual({ one: "search", other: "searches" });
  });

  it("freezes plural forms", () => {
    const label = readLabel({ other: "searches" }, "x");

    expect(Object.isFrozen(label)).toBe(true);
  });

  it("refuses a form that is not a string", () => {
    const error = thrown(() => readLabel({ other: 1 }, "x"));

    expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
  });
});

describe("readDisplaySymbol", () => {
  it("returns plural forms with an other key", () => {
    const label = readDisplaySymbol({ one: "search", other: "searches" }, "x");

    expect(label).toEqual({ one: "search", other: "searches" });
  });

  it("refuses plural forms without an other key", () => {
    const error = thrown(() => readDisplaySymbol({ one: "search" }, "x"));

    expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
  });
});

describe("readNullable", () => {
  it("returns null for null", () => {
    const value = readNullable(null, "x", readString);

    expect(value).toBeNull();
  });

  it("reads anything else", () => {
    const value = readNullable("g", "x", readString);

    expect(value).toBe("g");
  });

  it("refuses a missing key", () => {
    const error = thrown(() => readNullable(undefined, "x", readString));

    expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
  });
});
