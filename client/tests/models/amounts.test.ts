import { describe, expect, it } from "vitest";

import { Amount } from "@/models/amount.js";
import { Amounts } from "@/models/amounts.js";
import { manifestWith, testAmounts, testManifest, thrown } from "@tests/helpers/fixtures.js";

const amounts = testAmounts();
const germanAmounts = testAmounts({ locale: "de" });

describe("Amounts", () => {
  describe("fromManifest", () => {
    it("builds a client from the gem's manifest", () => {
      const manifest = testManifest();
      const client = Amounts.fromManifest(manifest);

      expect(client).toBeInstanceOf(Amounts);
    });

    it("has no locale by default", () => {
      expect(amounts.locale).toBeNull();
    });

    it("keeps the given locale", () => {
      expect(germanAmounts.locale).toBe("de");
    });

    it("refuses a locale the manifest lacks", () => {
      const manifest = testManifest();
      const error = thrown(() => Amounts.fromManifest(manifest, { locale: "ja" }));

      expect(error).toMatchObject({ code: "UNKNOWN_LOCALE" });
    });

    it("refuses a malformed manifest", () => {
      const manifest = manifestWith("types.USDC.decimals", "6");
      const error = thrown(() => Amounts.fromManifest(manifest));

      expect(error).toMatchObject({ code: "INVALID_MANIFEST" });
    });

    it("is frozen", () => {
      const frozen = Object.isFrozen(amounts);

      expect(frozen).toBe(true);
    });
  });

  describe("of", () => {
    it("reads a bigint as atomic", () => {
      const amount = amounts.of("USDC", 1_500_000n);

      expect(amount.atomic).toBe(1500000n);
    });

    it("reads a string as a UI value", () => {
      const amount = amounts.of("USDC", "1.50");

      expect(amount.atomic).toBe(1500000n);
    });

    it("reads a number as a UI value, through its string form", () => {
      const amount = amounts.of("USDC", 1.5);

      expect(amount.atomic).toBe(1500000n);
    });

    it("reads 0.1 exactly", () => {
      const amount = amounts.of("USDC", 0.1);

      expect(amount.atomic).toBe(100000n);
    });

    it("truncates excess UI decimals toward zero, as the gem does", () => {
      const amount = amounts.of("USDC", "1.1234567");

      expect(amount.atomic).toBe(1123456n);
    });

    it("truncates a negative UI value toward zero", () => {
      const amount = amounts.of("USDC", "-1.9999999");

      expect(amount.atomic).toBe(-1999999n);
    });

    it("reads an exponent", () => {
      const amount = amounts.of("USDC", "1e3");

      expect(amount.atomic).toBe(1000000000n);
    });

    it("reads a digit string as atomic with from atomic", () => {
      const amount = amounts.of("USDC", "1500000", { from: "atomic" });

      expect(amount.atomic).toBe(1500000n);
    });

    it("reads an integer number as atomic with from atomic", () => {
      const amount = amounts.of("USDC", 1500000, { from: "atomic" });

      expect(amount.atomic).toBe(1500000n);
    });

    it("reads a bigint as whole units with from ui", () => {
      const amount = amounts.of("USDC", 2n, { from: "ui" });

      expect(amount.atomic).toBe(2000000n);
    });

    it("refuses a decimal string with from atomic", () => {
      const error = thrown(() => amounts.of("USDC", "1.5", { from: "atomic" }));

      expect(error).toMatchObject({ code: "INVALID_INPUT" });
    });

    it("refuses an unsafe integer number with from atomic", () => {
      const error = thrown(() => amounts.of("USDC", 2 ** 60, { from: "atomic" }));

      expect(error).toMatchObject({ code: "INVALID_INPUT" });
    });

    it("refuses an unknown format", () => {
      const options = { from: "float" } as unknown as { from: "ui" };
      const error = thrown(() => amounts.of("USDC", "1", options));

      expect(error).toMatchObject({ message: 'unknown amount format: "float"' });
    });

    it("refuses text that is not a number", () => {
      const error = thrown(() => amounts.of("USDC", "abc"));

      expect(error).toMatchObject({ message: 'cannot parse "abc" as USDC' });
    });

    it("refuses a value it can't infer", () => {
      const value = {} as unknown as string;
      const error = thrown(() => amounts.of("USDC", value));

      expect(error).toMatchObject({ message: "cannot infer type for object" });
    });

    it("refuses an unregistered symbol", () => {
      const error = thrown(() => amounts.of("DOGE", "1"));

      expect(error).toMatchObject({ code: "UNKNOWN_TYPE" });
    });

    it("builds an Amount", () => {
      const amount = amounts.of("USDC", "1");

      expect(amount).toBeInstanceOf(Amount);
    });

    it("builds amounts that know their client", () => {
      const amount = germanAmounts.of("USD", "1500.5");

      expect(amount.amounts).toBe(germanAmounts);
    });
  });

  describe("parse", () => {
    it("reads the compact string", () => {
      const amount = amounts.parse("USDC|1.50");

      expect(amount.atomic).toBe(1500000n);
    });

    it("reads the versioned compact string", () => {
      const amount = amounts.parse("v1:USDC|1.50");

      expect(amount.atomic).toBe(1500000n);
    });

    it("reads a negative value", () => {
      const amount = amounts.parse("USDC|-1.500000");

      expect(amount.atomic).toBe(-1500000n);
    });

    it("reads back what toJSON writes", () => {
      const original = amounts.of("ETH", 123456789012345678901234567890n);
      const json = original.toJSON();
      const parsed = amounts.parse(json);

      expect(parsed.atomic).toBe(123456789012345678901234567890n);
    });

    it("refuses an unparseable value, naming the value", () => {
      const error = thrown(() => amounts.parse("USDC|abc"));

      expect(error).toMatchObject({ message: 'cannot parse "abc" as USDC' });
    });

    it("refuses an unregistered symbol", () => {
      const error = thrown(() => amounts.parse("DOGE|1"));

      expect(error).toMatchObject({ code: "UNKNOWN_TYPE" });
    });
  });

  describe("parseUi", () => {
    it("reads plain input", () => {
      const amount = amounts.parseUi("1500.50", "USD");

      expect(amount.atomic).toBe(150050n);
    });

    it("reads input in the given locale", () => {
      const amount = amounts.parseUi("1.500,50", "USD", { locale: "de" });

      expect(amount.atomic).toBe(150050n);
    });

    it("reads input in the client's locale", () => {
      const amount = germanAmounts.parseUi("1.500,50", "USD");

      expect(amount.atomic).toBe(150050n);
    });

    it("refuses an unregistered symbol", () => {
      const error = thrown(() => amounts.parseUi("1", "DOGE"));

      expect(error).toMatchObject({ code: "UNKNOWN_TYPE" });
    });

    it("refuses a locale the manifest lacks", () => {
      const error = thrown(() => amounts.parseUi("1", "USD", { locale: "ja" }));

      expect(error).toMatchObject({ code: "UNKNOWN_LOCALE" });
    });
  });

  describe("load", () => {
    it("reads the versioned payload", () => {
      const amount = amounts.load({ v: 1, atomic: "1500000", symbol: "USDC" });

      expect(amount.atomic).toBe(1500000n);
    });

    it("reads a payload without a version", () => {
      const amount = amounts.load({ atomic: "1500000", symbol: "USDC" });

      expect(amount.atomic).toBe(1500000n);
    });

    it("reads back what toHash writes", () => {
      const original = amounts.of("USDC", "-2.25");
      const hash = original.toHash();
      const loaded = amounts.load(hash);
      const equal = loaded.equals(original);

      expect(equal).toBe(true);
    });

    it("refuses another version", () => {
      const error = thrown(() => amounts.load({ v: 2, atomic: "1", symbol: "USDC" }));

      expect(error).toMatchObject({ message: "unsupported amount serialization version: 2" });
    });

    it("refuses a payload without atomic", () => {
      const payload = { v: 1, symbol: "USDC" } as unknown as { atomic: string; symbol: string };
      const error = thrown(() => amounts.load(payload));

      expect(error).toMatchObject({ message: "amount payload missing key: atomic" });
    });

    it("refuses a payload without symbol", () => {
      const payload = { v: 1, atomic: "1" } as unknown as { atomic: string; symbol: string };
      const error = thrown(() => amounts.load(payload));

      expect(error).toMatchObject({ message: "amount payload missing key: symbol" });
    });

    it("refuses something that is not an object", () => {
      const payload = "USDC|1" as unknown as { atomic: string; symbol: string };
      const error = thrown(() => amounts.load(payload));

      expect(error).toMatchObject({ code: "INVALID_INPUT" });
    });
  });

  describe("localeFor", () => {
    it("is null without a locale", () => {
      const locale = amounts.localeFor(undefined);

      expect(locale).toBeNull();
    });

    it("is the client's locale when none is given", () => {
      const locale = germanAmounts.localeFor(null);

      expect(locale?.name).toBe("de");
    });

    it("is the given locale over the client's", () => {
      const locale = germanAmounts.localeFor("fr");

      expect(locale?.name).toBe("fr");
    });
  });
});
