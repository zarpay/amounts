import { describe, expect, it } from "vitest";

import * as client from "@/index.js";

describe("index", () => {
  it("exports exactly the public classes", () => {
    const names = Object.keys(client).sort();

    expect(names).toEqual([
      "Amount",
      "AmountError",
      "Amounts",
      "Ratio",
      "Registry",
      "RegistryEntry",
    ]);
  });
});
