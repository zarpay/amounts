import { describe, expect, it } from "vitest";

import { fillTemplate, isValidTemplate } from "@/helpers/template-helper.js";

describe("isValidTemplate", () => {
  it("accepts a template that places the number", () => {
    const valid = isValidTemplate("%n %u");

    expect(valid).toBe(true);
  });

  it("refuses a template without the number", () => {
    const valid = isValidTemplate("%u");

    expect(valid).toBe(false);
  });

  it("refuses a non-string", () => {
    const valid = isValidTemplate(null);

    expect(valid).toBe(false);
  });
});

describe("fillTemplate", () => {
  it("places the number and the label", () => {
    const filled = fillTemplate("%u%n", "1.50", "$");

    expect(filled).toBe("$1.50");
  });

  it("copies everything else as given", () => {
    const filled = fillTemplate("%n %u", "12,50", "€");

    expect(filled).toBe("12,50 €");
  });

  it("never reads a placeholder inside the label", () => {
    const filled = fillTemplate("%n %u", "5", "%n");

    expect(filled).toBe("5 %n");
  });

  it("fills a template without a label", () => {
    const filled = fillTemplate("%n doz", "3", "x");

    expect(filled).toBe("3 doz");
  });
});
