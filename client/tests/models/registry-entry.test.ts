import { describe, expect, it } from "vitest";

import { RegistryEntry } from "@/models/registry-entry.js";
import { testManifest, thrown } from "@tests/helpers/fixtures.js";

/** An entry built from the exported manifest's type. */
function entry(symbol: string, overrides: Record<string, unknown> = {}): RegistryEntry {
  const manifest = testManifest();
  const types = manifest["types"] as Record<string, Record<string, unknown>>;
  const type = { ...types[symbol], ...overrides };

  return RegistryEntry.fromManifest(symbol, type, `types.${symbol}`);
}

describe("RegistryEntry", () => {
  describe("fromManifest", () => {
    it("keeps the symbol", () => {
      const usdc = entry("USDC");

      expect(usdc.symbol).toBe("USDC");
    });

    it("reads decimals", () => {
      const usdc = entry("USDC");

      expect(usdc.decimals).toBe(6);
    });

    it("reads the display symbol", () => {
      const usdc = entry("USDC");

      expect(usdc.displaySymbol).toBe("$");
    });

    it("reads plural display symbols", () => {
      const searches = entry("SEARCHES");

      expect(searches.displaySymbol).toEqual({ one: "search", other: "searches" });
    });

    it("reads the display format", () => {
      const usdc = entry("USDC");

      expect(usdc.displayFormat).toBe("%u%n");
    });

    it("reads ui decimals", () => {
      const usdc = entry("USDC");

      expect(usdc.uiDecimals).toBe(2);
    });

    it("reads trim zeros", () => {
      const sol = entry("SOL");

      expect(sol.trimZeros).toBe(true);
    });

    it("reads no display units as null", () => {
      const usdc = entry("USDC");

      expect(usdc.displayUnits).toBeNull();
    });

    it("reads the default display", () => {
      const gold = entry("GOLD");

      expect(gold.defaultDisplay).toBe("oz_t");
    });

    it("reads a display unit camelCased", () => {
      const gold = entry("GOLD");

      expect(gold.displayUnits?.["kg"]).toEqual({
        scale: "0.0311034768",
        symbol: "kg",
        uiDecimals: 5,
        format: null,
        trimZeros: true,
      });
    });

    it("reads a display unit's resolved position", () => {
      const gold = entry("GOLD");

      expect(gold.displayUnits?.["grain"]?.format).toBe("%u%n");
    });

    it("refuses a negative decimals", () => {
      const error = thrown(() => entry("USDC", { decimals: -1 }));

      expect(error).toMatchObject({
        message: "invalid manifest: types.USDC.decimals must be a non-negative integer",
      });
    });

    it("refuses a missing key", () => {
      const error = thrown(() => entry("USDC", { trim_zeros: undefined }));

      expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
    });

    it("refuses a display format without the number", () => {
      const error = thrown(() => entry("USDC", { display_format: "%u" }));

      expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
    });

    it("refuses a display unit scale that is not a decimal", () => {
      const units = {
        gram: { scale: "lots", symbol: "g", ui_decimals: 2, format: null, trim_zeros: null },
      };
      const error = thrown(() => entry("GOLD", { display_units: units }));

      expect(error).toMatchObject({
        message: "invalid manifest: types.GOLD.display_units.gram.scale must be a decimal string",
      });
    });

    it("is frozen", () => {
      const usdc = entry("USDC");

      expect(Object.isFrozen(usdc)).toBe(true);
    });
  });

  describe("displayUnit", () => {
    it("returns the unit's spec", () => {
      const gold = entry("GOLD");
      const gram = gold.displayUnit("gram");

      expect(gram.scale).toBe("31.1034768");
    });

    it("refuses an unknown unit", () => {
      const gold = entry("GOLD");
      const error = thrown(() => gold.displayUnit("stone"));

      expect(error).toMatchObject({ message: "unknown display unit stone for GOLD" });
    });

    it("refuses a type without display units", () => {
      const usd = entry("USD");
      const error = thrown(() => usd.displayUnit("gram"));

      expect(error).toMatchObject({ message: "USD has no display_units configured" });
    });
  });
});
