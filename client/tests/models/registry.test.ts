import { describe, expect, it } from "vitest";

import { Registry } from "@/models/registry.js";
import { manifestWith, testManifest, thrown } from "@tests/helpers/fixtures.js";

function registry(): Registry {
  const manifest = testManifest();

  return Registry.fromManifest(manifest);
}

const exported = registry();

describe("Registry", () => {
  describe("fromManifest", () => {
    it("refuses something that is not an object", () => {
      const error = thrown(() => Registry.fromManifest("USDC"));

      expect(error).toMatchObject({ message: "invalid manifest: manifest must be an object" });
    });

    it("refuses another manifest version", () => {
      const manifest = manifestWith("v", 2);
      const error = thrown(() => Registry.fromManifest(manifest));

      expect(error).toMatchObject({ message: "invalid manifest: v must be 1" });
    });

    it("refuses types that are not an object", () => {
      const manifest = manifestWith("types", []);
      const error = thrown(() => Registry.fromManifest(manifest));

      expect(error).toMatchObject({ message: "invalid manifest: types must be an object" });
    });

    it("refuses rates that are not an array", () => {
      const manifest = manifestWith("rates", {});
      const error = thrown(() => Registry.fromManifest(manifest));

      expect(error).toMatchObject({ message: "invalid manifest: rates must be an array" });
    });

    it("refuses a rate between unregistered symbols", () => {
      const manifest = manifestWith("rates", [{ from: "DOGE", to: "USD", rate: "1" }]);
      const error = thrown(() => Registry.fromManifest(manifest));

      expect(error).toMatchObject({
        message: "invalid manifest: rates.0.from must be a registered symbol",
      });
    });

    it("refuses a rate that is not a decimal string", () => {
      const manifest = manifestWith("rates", [{ from: "USD", to: "USDC", rate: 1 }]);
      const error = thrown(() => Registry.fromManifest(manifest));

      expect(error).toMatchObject({
        message: "invalid manifest: rates.0.rate must be a decimal string",
      });
    });

    it("refuses a malformed type, naming its path", () => {
      const manifest = manifestWith("types.SOL.ui_decimals", "4");
      const error = thrown(() => Registry.fromManifest(manifest));

      expect(error).toMatchObject({
        message: "invalid manifest: types.SOL.ui_decimals must be a non-negative integer",
      });
    });

    it("refuses a malformed locale, naming its path", () => {
      const manifest = manifestWith("locales.de.number.separator", 1);
      const error = thrown(() => Registry.fromManifest(manifest));

      expect(error).toMatchObject({
        message: "invalid manifest: locales.de.number.separator must be a string",
      });
    });

    it("is frozen", () => {
      const built = registry();

      expect(Object.isFrozen(built)).toBe(true);
    });
  });

  describe("symbols", () => {
    it("lists the symbols in registration order", () => {
      const symbols = exported.symbols;

      expect(symbols).toEqual([
        "USDC",
        "USD",
        "SOL",
        "GOLD",
        "LOGS",
        "SEARCHES",
        "EUR",
        "TOKENS",
        "ETH",
        "BARE",
      ]);
    });
  });

  describe("localeNames", () => {
    it("lists the exported locales", () => {
      const names = exported.localeNames;

      expect(names).toEqual(["en", "de", "fr"]);
    });
  });

  describe("registered", () => {
    it("is true for a registered symbol", () => {
      const registered = exported.registered("USDC");

      expect(registered).toBe(true);
    });

    it("is false for an unknown symbol", () => {
      const registered = exported.registered("DOGE");

      expect(registered).toBe(false);
    });
  });

  describe("lookup", () => {
    it("returns the entry", () => {
      const entry = exported.lookup("SOL");

      expect(entry.decimals).toBe(9);
    });

    it("refuses an unknown symbol", () => {
      const built = registry();
      const error = thrown(() => built.lookup("DOGE"));

      expect(error).toMatchObject({ code: "UNKNOWN_TYPE", message: "DOGE is not registered" });
    });
  });

  describe("defaultRate", () => {
    it("returns the rate as written", () => {
      const rate = exported.defaultRate("USDC", "SOL");

      expect(rate).toBe("0.0066666666");
    });

    it("returns a Rational rate as the gem uses it", () => {
      const rate = exported.defaultRate("USDC", "EUR");

      expect(rate).toBe("0.3333333333333333333");
    });

    it("never inverts a rate", () => {
      const built = registry();
      const error = thrown(() => built.defaultRate("SOL", "USDC"));

      expect(error).toMatchObject({ code: "NO_DEFAULT_RATE" });
    });
  });

  describe("hasDefaultRate", () => {
    it("is true for a registered direction", () => {
      const present = exported.hasDefaultRate("USD", "USDC");

      expect(present).toBe(true);
    });

    it("is false for the other direction", () => {
      const present = exported.hasDefaultRate("EUR", "USDC");

      expect(present).toBe(false);
    });
  });

  describe("locale", () => {
    it("returns the locale's table", () => {
      const locale = exported.locale("fr");

      expect(locale.delimiter).toBe(" ");
    });

    it("refuses a locale the manifest lacks", () => {
      const built = registry();
      const error = thrown(() => built.locale("ja"));

      expect(error).toMatchObject({ code: "UNKNOWN_LOCALE" });
    });
  });
});
