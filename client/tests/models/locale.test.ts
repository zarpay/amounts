import { describe, expect, it } from "vitest";

import { Locale } from "@/models/locale.js";
import { Ratio } from "@/models/ratio.js";
import { testManifest, thrown } from "@tests/helpers/fixtures.js";

/** The exported German table: the one with translations. */
function german(): Locale {
  const manifest = testManifest();
  const locales = manifest["locales"] as Record<string, unknown>;

  return Locale.fromManifest("de", locales["de"], "locales.de");
}

const de = german();
const plural = { one: "search", other: "searches" };
const withZero = { zero: "none", one: "search", other: "searches" };
const zero = Ratio.of(0n);
const one = Ratio.of(1n);
const two = Ratio.of(2n);

describe("Locale", () => {
  describe("fromManifest", () => {
    it("keeps the locale's name", () => {
      const locale = german();

      expect(locale.name).toBe("de");
    });

    it("reads the delimiter", () => {
      const locale = german();

      expect(locale.delimiter).toBe(".");
    });

    it("reads the separator", () => {
      const locale = german();

      expect(locale.separator).toBe(",");
    });

    it("reads the compact format", () => {
      const locale = german();

      expect(locale.compactFormat).toBe("%n %u");
    });

    it("refuses a table without number formats", () => {
      const error = thrown(() =>
        Locale.fromManifest("xx", { compact: {}, types: {} }, "locales.xx"),
      );

      expect(error).toMatchObject({
        message: "invalid manifest: locales.xx.number must be an object",
      });
    });

    it("refuses a compact format that drops the number", () => {
      const table = {
        number: { delimiter: ",", separator: "." },
        compact: { format: "%u", units: {} },
        types: {},
      };
      const error = thrown(() => Locale.fromManifest("xx", table, "locales.xx"));

      expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
    });

    it("is frozen", () => {
      const locale = german();

      expect(Object.isFrozen(locale)).toBe(true);
    });
  });

  describe("lookups", () => {
    it("reads a scale word", () => {
      const word = de.compactUnit("thousand");

      expect(word).toBe("Tsd.");
    });

    it("reads a plural scale word whole", () => {
      const word = de.compactUnit("million");

      expect(word).toEqual({ one: "Million", other: "Millionen" });
    });

    it("returns null for an untranslated scale word", () => {
      const word = de.compactUnit("billion");

      expect(word).toBeNull();
    });

    it("reads a type's label", () => {
      const label = de.typeLabel("GOLD");

      expect(label).toBe("Feinunze");
    });

    it("returns null for an untranslated type label", () => {
      const label = de.typeLabel("USD");

      expect(label).toBeNull();
    });

    it("returns null for a type the table doesn't know", () => {
      const label = de.typeLabel("DOGE");

      expect(label).toBeNull();
    });

    it("reads a type's format", () => {
      const format = de.typeFormat("EUR");

      expect(format).toBe("%n %u");
    });

    it("reads a display unit's label", () => {
      const label = de.unitLabel("GOLD", "gram");

      expect(label).toBe("Gramm");
    });

    it("reads a display unit's format", () => {
      const format = de.unitFormat("GOLD", "kg");

      expect(format).toBe("%n %u");
    });

    it("returns null for an untranslated display unit format", () => {
      const format = de.unitFormat("GOLD", "gram");

      expect(format).toBeNull();
    });
  });

  describe("applyNumber", () => {
    it("groups thousands with the delimiter", () => {
      const number = de.applyNumber("1234567");

      expect(number).toBe("1.234.567");
    });

    it("writes the separator", () => {
      const number = de.applyNumber("1500.50");

      expect(number).toBe("1.500,50");
    });

    it("keeps the sign", () => {
      const number = de.applyNumber("-1234.5");

      expect(number).toBe("-1.234,5");
    });

    it("leaves a short number ungrouped", () => {
      const number = de.applyNumber("999");

      expect(number).toBe("999");
    });
  });

  describe("plain", () => {
    it("passes a string through", () => {
      const label = Locale.plain("$", two);

      expect(label).toBe("$");
    });

    it("picks one for a count of exactly 1", () => {
      const label = Locale.plain(plural, one);

      expect(label).toBe("search");
    });

    it("picks other for zero, ignoring a zero form", () => {
      const label = Locale.plain(withZero, zero);

      expect(label).toBe("searches");
    });

    it("picks other without a count", () => {
      const label = Locale.plain(plural, null);

      expect(label).toBe("searches");
    });
  });

  describe("pluralize", () => {
    it("picks one for a count of 1", () => {
      const label = Locale.pluralize(plural, one);

      expect(label).toBe("search");
    });

    it("picks the zero form for zero, when present", () => {
      const label = Locale.pluralize(withZero, zero);

      expect(label).toBe("none");
    });

    it("picks other for zero without a zero form", () => {
      const label = Locale.pluralize(plural, zero);

      expect(label).toBe("searches");
    });

    it("falls back to other when the chosen form is missing", () => {
      const label = Locale.pluralize({ other: "searches" }, one);

      expect(label).toBe("searches");
    });

    it("picks other without a count", () => {
      const label = Locale.pluralize(plural, null);

      expect(label).toBe("searches");
    });

    it("returns null when there is no form to pick", () => {
      const label = Locale.pluralize({ one: "search" }, two);

      expect(label).toBeNull();
    });
  });
});
