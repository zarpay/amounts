import type { Locale } from "@/models/locale.js";
import type { RegistryEntry } from "@/models/registry-entry.js";
import type {
  AmountHash,
  AmountInput,
  AmountInputFormat,
  AmountOfOptions,
  AmountsOptions,
  AmountsParseUiOptions,
} from "@/types.js";

import { errors } from "@/helpers/errors-helper.js";
import { Amount } from "@/models/amount.js";
import { Parser } from "@/models/parser.js";
import { Ratio } from "@/models/ratio.js";
import { Registry } from "@/models/registry.js";
import { UiParser } from "@/models/ui-parser.js";

/** The only `v` a `toHash` payload may carry (or none at all). */
const SERIALIZATION_VERSION = 1;
/** An atomic count written as text: an optional sign and digits, nothing else. */
const ATOMIC_DIGITS = /^[+-]?\d+$/;

/**
 * The client: everything the gem's `Amount` class offers at class level,
 * built from the registry the gem exported.
 *
 * The server owns the registry. It registers types and rates in its
 * initializer and exports them with `Amount.manifest`; the client is
 * constructed from that export and never registers anything itself, so
 * the frontend and the server can't disagree about a type's decimals, a
 * rate or a label.
 *
 * Construct one client per manifest — typically once, at app start — and
 * share it. It is immutable and holds no state beyond the manifest and an
 * optional default locale. Every {@link Amount} it builds keeps a
 * reference to it, for conversions and display.
 *
 * | Gem | Client |
 * | --- | --- |
 * | `Amount.new(value, :SYM)`, `Amount.of_sym(value)` | {@link of} |
 * | `Amount.parse` | {@link parse} |
 * | `Amount.parse_ui` | {@link parseUi} |
 * | `Amount.load` | {@link load} |
 * | `Amount.registry` | {@link registry} |
 * | `Amount.localize = true` + `I18n.locale` | `fromManifest(m, { locale })` |
 *
 * @example
 *   import { Amounts } from "@zarpay/amounts";
 *
 *   const manifest = await (await fetch("/amounts/manifest")).json();
 *   const amounts = Amounts.fromManifest(manifest);
 *
 *   amounts.of("USDC", "1.50").add(amounts.parse("USDC|0.50")).ui();  // "$2.00"
 */
export class Amounts {
  /** The registered types, default rates and locale tables, from the manifest. */
  readonly registry: Registry;
  /**
   * The locale display and input use when a call names none, or `null` for
   * plain output (no delimiters, `.` decimal separator, untranslated labels).
   */
  readonly locale: string | null;

  private constructor(registry: Registry, locale: string | null) {
    this.registry = registry;
    this.locale = locale;
    Object.freeze(this);
  }

  /**
   * Builds a client from a manifest the gem exported.
   *
   * The whole manifest is validated here, so a client that constructs is
   * complete: no later call fails on a missing or malformed key. Pass the
   * parsed JSON as-is; it's typed `unknown` because it comes off the wire.
   *
   * @param manifest - the parsed output of `Amount.manifest`
   * @param options - `locale`: make every call follow this locale when it
   *   names none, like the gem's `Amount.localize = true` with
   *   `I18n.locale`. It must be one of the locales the manifest was
   *   exported with.
   * @returns the client
   * @throws {@link AmountError} `INVALID_MANIFEST` naming the first
   *   malformed path (`types.USDC.decimals`), `UNKNOWN_LOCALE` for a locale
   *   the manifest lacks
   *
   * @example
   *   const amounts = Amounts.fromManifest(manifest);
   *   const german = Amounts.fromManifest(manifest, { locale: "de" });
   *
   *   german.of("USD", "1500.5").ui();  // "$1.500,50"
   */
  static fromManifest(manifest: unknown, options: AmountsOptions = {}): Amounts {
    const registry = Registry.fromManifest(manifest);
    const locale = options.locale ?? null;

    if (locale !== null) registry.locale(locale);

    return new Amounts(registry, locale);
  }

  /**
   * An amount of a registered type — the gem's `Amount.new` and its
   * generated `Amount.of_usdc` constructors.
   *
   * How the value is read depends on its JavaScript type:
   *
   * - **`bigint`** is a count of atomic units: `1_500_000n` USDC is 1.50.
   * - **`string`** is a value in whole units, read exactly in Ruby's
   *   `BigDecimal` grammar (`"1.50"`, `"1_000"`, `"1e3"`). Extra decimal
   *   places are truncated toward zero, as the gem truncates them.
   * - **`number`** is a value in whole units, read through its string form,
   *   so `0.1` is exactly one tenth — never `0.1000000000000000055…`.
   *
   * Ruby reads an `Integer` as atomic, but JavaScript can't tell `1` from
   * `1.0`, hence `bigint`. `options.from` overrides the inference: `"atomic"`
   * reads a digit string or safe-integer `number` as atomic units, `"ui"`
   * reads a `bigint` as whole units.
   *
   * @param symbol - a registered type
   * @param value - the value, read as described above
   * @param options - `from`: `"atomic"` or `"ui"`, overriding the inference
   * @returns the amount
   * @throws {@link AmountError} `UNKNOWN_TYPE` for an unregistered symbol,
   *   `INVALID_INPUT` for a value that can't be read
   *
   * @example
   *   amounts.of("USDC", 1_500_000n);                     // 1.50, atomic
   *   amounts.of("USDC", "1.50");                         // 1.50, whole units
   *   amounts.of("USDC", 1.5);                            // 1.50, through "1.5"
   *   amounts.of("USDC", "1500000", { from: "atomic" });  // 1.50, atomic from text
   *   amounts.of("ETH", 10n ** 18n);                      // 1 ETH, exact past 2^53
   */
  of(symbol: string, value: AmountInput, options: AmountOfOptions = {}): Amount {
    const entry = this.registry.lookup(symbol);
    const format = options.from ?? inferFormat(value);
    const atomic = readValue(value, format, entry);

    return new Amount(this, entry, atomic);
  }

  /**
   * Reads the compact string {@link Amount.toJSON} and the gem's `as_json`
   * write — the format amounts travel in over JSON — the gem's
   * `Amount.parse`.
   *
   * The string is a symbol, a bar and a value in whole units
   * (`"USDC|1.500000"`), optionally versioned (`"v1:USDC|1.50"`). The value
   * is read as {@link of} reads a string, so any number of places is
   * accepted.
   *
   * @param compact - `"SYMBOL|value"` or `"v1:SYMBOL|value"`
   * @returns the amount
   * @throws {@link AmountError} `INVALID_INPUT` for a malformed string or an
   *   unsupported version, `UNKNOWN_TYPE` for an unregistered symbol
   *
   * @example Reading an API response
   *   const { balance } = await (await fetch("/wallet")).json();  // "USDC|42.500000"
   *   amounts.parse(balance).ui();                                // "$42.50"
   */
  parse(compact: string): Amount {
    const parsed = Parser.parse(compact);

    return this.of(parsed.symbol, parsed.value);
  }

  /**
   * Reads what a person typed into a form field — the gem's
   * `Amount.parse_ui`.
   *
   * The number is read in a locale's format: `options.locale`, else the
   * client's locale, else plain (`.` decimal separator, no delimiters).
   * Accepted: surrounding whitespace, a leading `-` or `+`, delimiters in
   * groups of three, and the type's label (any plural form, or its
   * translation in the locale) at either end.
   *
   * It never rounds. More decimal places than the type stores is an error,
   * not a silent truncation, so a person never submits a value they
   * didn't type.
   *
   * @param input - the text as typed
   * @param symbol - the type it's an amount of
   * @param options - `locale`: the number format to read
   * @returns the amount
   * @throws {@link AmountError} `INVALID_INPUT` (empty, not a number, too
   *   many decimals, misplaced delimiters, a repeated separator, another
   *   type's label — the message says which), `UNKNOWN_TYPE`,
   *   `UNKNOWN_LOCALE`
   *
   * @example
   *   amounts.parseUi("1,500.50", "USD", { locale: "en" });  // USD 1500.50
   *   amounts.parseUi("1.500,50", "USD", { locale: "de" });  // USD 1500.50
   *   amounts.parseUi("$12.50", "USD");                      // USD 12.50
   *   amounts.parseUi("1.234", "USD");                       // throws: more than 2 decimal places
   */
  parseUi(input: string, symbol: string, options: AmountsParseUiOptions = {}): Amount {
    const entry = this.registry.lookup(symbol);
    const locale = this.localeFor(options.locale);
    const parser = new UiParser(input, entry, locale);
    const atomic = parser.parse();

    return new Amount(this, entry, atomic);
  }

  /**
   * Reads the versioned payload {@link Amount.toHash} and the gem's `to_h`
   * write — the gem's `Amount.load`. A payload without `v` is read as
   * version 1.
   *
   * @param payload - `{ v?: 1, atomic, symbol }`, with `atomic` as a digit
   *   string, `bigint` or safe integer
   * @returns the amount
   * @throws {@link AmountError} `INVALID_INPUT` for another version, a
   *   missing key or an unreadable atomic value, `UNKNOWN_TYPE`
   *
   * @example
   *   amounts.load({ v: 1, atomic: "1500000", symbol: "USDC" }).ui();  // "$1.50"
   */
  load(payload: AmountHash): Amount {
    if (typeof payload !== "object" || payload === null) {
      throw errors.invalidPayload("amount payload must be an object");
    }

    const version = payload.v;

    if (version !== undefined && version !== null && version !== SERIALIZATION_VERSION) {
      throw errors.invalidPayload(`unsupported amount serialization version: ${String(version)}`);
    }

    if (payload.atomic === undefined) {
      throw errors.invalidPayload("amount payload missing key: atomic");
    }

    if (payload.symbol === undefined) {
      throw errors.invalidPayload("amount payload missing key: symbol");
    }

    return this.of(payload.symbol, payload.atomic, { from: "atomic" });
  }

  /**
   * The locale table a call uses — the gem's `Locale.effective`: the
   * explicit locale when one is given, else the client's, else `null` for
   * plain output. Used by {@link Amount} display and {@link parseUi}.
   *
   * @param explicit - the locale a call named, if any
   * @returns the locale's table, or `null`
   * @throws {@link AmountError} `UNKNOWN_LOCALE` for a locale the manifest lacks
   */
  localeFor(explicit: string | null | undefined): Locale | null {
    const name = explicit ?? this.locale;

    return name === null ? null : this.registry.locale(name);
  }
}

/** The format a value is read in when `from` isn't given: `bigint` atomic, else whole units. */
function inferFormat(value: unknown): AmountInputFormat {
  if (typeof value === "bigint") return "atomic";

  if (typeof value === "string" || typeof value === "number") return "ui";

  throw errors.cannotInfer(value);
}

/** The atomic value of `value` read in `format`. */
function readValue(value: AmountInput, format: AmountInputFormat, entry: RegistryEntry): bigint {
  if (format === "atomic") return readAtomic(value);

  if (format === "ui") return readUi(value, entry);

  throw errors.unknownFormat(format);
}

/**
 * An atomic count. Stricter than Ruby's `to_i`, which reads `"12abc"` as
 * 12: anything but an integer is refused.
 */
function readAtomic(value: unknown): bigint {
  if (typeof value === "bigint") return value;

  if (typeof value === "number" && Number.isSafeInteger(value)) return BigInt(value);

  if (typeof value === "string" && ATOMIC_DIGITS.test(value)) return BigInt(value);

  throw errors.cannotParse(value);
}

/** Whole units to atomic: the exact value times `10 ** decimals`, truncated toward zero. */
function readUi(value: AmountInput, entry: RegistryEntry): bigint {
  const parsed = Ratio.parse(value);

  if (parsed === null) throw errors.cannotParse(value, entry.symbol);

  const unit = Ratio.powerOfTen(entry.decimals);
  const scaled = parsed.multiply(unit);

  return scaled.truncate();
}
