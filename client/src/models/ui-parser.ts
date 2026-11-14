import type { Locale } from "@/models/locale.js";
import type { RegistryEntry } from "@/models/registry-entry.js";
import type { Label } from "@/types.js";

import { errors } from "@/helpers/errors-helper.js";

/**
 * Reads what a person typed into a form field, optionally in a locale's
 * number format. The gem's `Amount::UiParser`: exact, never rounds.
 *
 * Accepts surrounding whitespace, a leading `-` or `+`, delimiters in
 * groups of three, and the type's label (any plural form) at either end.
 */
export class UiParser {
  private readonly input: string;
  private readonly entry: RegistryEntry;
  private readonly locale: Locale | null;
  private readonly delimiter: string;
  private readonly separator: string;

  constructor(input: string, entry: RegistryEntry, locale: Locale | null) {
    this.input = input;
    this.entry = entry;
    this.locale = locale;
    this.delimiter = locale?.delimiter ?? "";
    this.separator = locale?.separator ?? ".";
  }

  /**
   * The signed atomic value.
   *
   * @throws AmountError INVALID_INPUT for too many decimals, misplaced
   *   delimiters, a repeated separator, another type's label, or empty input
   */
  parse(): bigint {
    const text = strip(String(this.input));

    if (text === "") throw this.failure("is empty");

    const [leadingSign, unsigned] = takeSign(text);
    const signed = unsigned !== text;
    const unlabeled = this.stripLabel(unsigned);
    // "$-1.50": a sign may follow a prefix label, but not as a second sign
    const signAfterLabel = leadingSign === "" && unlabeled !== unsigned && !signed;
    const [sign, digits] = signAfterLabel ? takeSign(unlabeled) : [leadingSign, unlabeled];
    const value = this.atomic(digits);

    return sign === "-" ? -value : value;
  }

  private failure(reason: string): Error {
    return errors.cannotParseUi(this.input, this.entry.symbol, reason);
  }

  /** Removes one label (the longest match) from either end. */
  private stripLabel(text: string): string {
    for (const label of this.labels()) {
      if (text.startsWith(label)) return strip(text.slice(label.length));

      if (text.endsWith(label)) return strip(text.slice(0, text.length - label.length));
    }

    return text;
  }

  /** Every form of the type's label, plus its translation when localizing; longest first. */
  private labels(): string[] {
    const translation = this.locale?.typeLabel(this.entry.symbol) ?? null;
    const symbolForms = forms(this.entry.displaySymbol);
    const translatedForms = this.locale === null ? [] : forms(translation);
    const all = [...symbolForms, ...translatedForms].filter((label) => label !== "");
    const unique = [...new Set(all)];

    return unique.sort((left, right) => right.length - left.length);
  }

  /** The unsigned atomic value of a number in the locale's format. */
  private atomic(text: string): bigint {
    const [whole = "", fraction = "", ...extra] = text.split(this.separator);

    if (extra.length > 0) throw this.failure("a decimal separator is used twice");

    if (!this.wholePattern().test(whole)) throw this.failure("is not a number");

    if (text.includes(this.separator) && fraction === "") throw this.failure("is not a number");

    if (!/^\d*$/.test(fraction)) throw this.failure("is not a number");

    if (fraction.length > this.entry.decimals) {
      throw this.failure(`has more than ${this.entry.decimals} decimal places`);
    }

    const wholeDigits = whole.replace(/\D/g, "");
    const fractionDigits = fraction.padEnd(this.entry.decimals, "0");

    return BigInt(`${wholeDigits}${fractionDigits}`);
  }

  private wholePattern(): RegExp {
    if (this.delimiter === "") return /^\d+$/;

    const glue = /^\s+$/.test(this.delimiter) ? "\\s" : escapeRegExp(this.delimiter);

    return new RegExp(`^(?:\\d+|\\d{1,3}(?:${glue}\\d{3})+)$`);
  }
}

function strip(text: string): string {
  return text.replace(/^\s+|\s+$/g, "");
}

/** `"-"` or `""` (a `"+"` is dropped), and the rest. */
function takeSign(text: string): [string, string] {
  const match = /^([+-])\s*([\s\S]*)$/.exec(text);

  if (!match) return ["", text];

  const [, sign, rest = ""] = match;

  return [sign === "-" ? "-" : "", rest];
}

function forms(label: Label | null): string[] {
  if (label === null) return [];

  if (typeof label === "string") return [label];

  return Object.values(label);
}

function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
