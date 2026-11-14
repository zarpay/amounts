import { describe, expect, it } from "vitest";

import { Parser } from "@/models/parser.js";
import { thrown } from "@tests/helpers/fixtures.js";

describe("Parser", () => {
  describe("parse", () => {
    it("reads the symbol", () => {
      const parsed = Parser.parse("USDC|1.50");

      expect(parsed.symbol).toBe("USDC");
    });

    it("reads the value as written", () => {
      const parsed = Parser.parse("USDC|1.50");

      expect(parsed.value).toBe("1.50");
    });

    it("reads the versioned form", () => {
      const parsed = Parser.parse("v1:USDC|1.50");

      expect(parsed.symbol).toBe("USDC");
    });

    it("keeps everything after the first bar in the value", () => {
      const parsed = Parser.parse("USDC|1|2");

      expect(parsed.value).toBe("1|2");
    });

    it("refuses an unsupported version", () => {
      const error = thrown(() => Parser.parse("v2:USDC|1.50"));

      expect(error).toMatchObject({ message: 'cannot parse "v2:USDC|1.50"' });
    });

    it("refuses a missing value", () => {
      const error = thrown(() => Parser.parse("USDC|"));

      expect(error).toMatchObject({ code: "INVALID_INPUT" });
    });

    it("refuses a missing symbol", () => {
      const error = thrown(() => Parser.parse("|1.5"));

      expect(error).toMatchObject({ code: "INVALID_INPUT" });
    });

    it("refuses a string without a bar", () => {
      const error = thrown(() => Parser.parse("USDC"));

      expect(error).toMatchObject({ code: "INVALID_INPUT" });
    });

    it("refuses an empty string", () => {
      const error = thrown(() => Parser.parse(""));

      expect(error).toMatchObject({ code: "INVALID_INPUT" });
    });
  });
});
