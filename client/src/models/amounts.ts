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

const SERIALIZATION_VERSION = 1;
const ATOMIC_DIGITS = /^[+-]?\d+$/;

/**
 * The client: a mirror of the gem's `Amount` class methods, built from the
 * registry the gem exported (`Amount.manifest`).
 *
 * @example
 *   const amounts = Amounts.fromManifest(manifest);
 *   amounts.of("USDC", "1.50").add(amounts.parse("USDC|0.50")).ui(); // "$2.00"
 */
export class Amounts {
  readonly registry: Registry;
  /** The locale used when a call gives none; `null` for plain output. */
  readonly locale: string | null;

  private constructor(registry: Registry, locale: string | null) {
    this.registry = registry;
    this.locale = locale;
    Object.freeze(this);
  }

  /**
   * Builds a client from a manifest. `locale` makes output and input follow
   * that locale when a call gives none — the gem's `Amount.localize = true`
   * with `I18n.locale`.
   *
   * @throws AmountError INVALID_MANIFEST, UNKNOWN_LOCALE
   */
  static fromManifest(manifest: unknown, options: AmountsOptions = {}): Amounts {
    const registry = Registry.fromManifest(manifest);
    const locale = options.locale ?? null;

    if (locale !== null) registry.locale(locale);

    return new Amounts(registry, locale);
  }

  /**
   * An amount of a registered type: `bigint` is atomic, `string` and
   * `number` are UI values; `from` overrides that. The gem's `Amount.new`.
   *
   * @throws AmountError UNKNOWN_TYPE, INVALID_INPUT
   */
  of(symbol: string, value: AmountInput, options: AmountOfOptions = {}): Amount {
    const entry = this.registry.lookup(symbol);
    const format = options.from ?? inferFormat(value);
    const atomic = readValue(value, format, entry);

    return new Amount(this, entry, atomic);
  }

  /**
   * Reads the compact string `toJSON` writes: `"USDC|1.50"`, or
   * `"v1:USDC|1.50"`. The gem's `Amount.parse`.
   *
   * @throws AmountError INVALID_INPUT, UNKNOWN_TYPE
   */
  parse(compact: string): Amount {
    const parsed = Parser.parse(compact);

    return this.of(parsed.symbol, parsed.value);
  }

  /**
   * Reads what a person typed, in the locale's number format: the given
   * locale, else the client's, else plain (`.` decimal, no delimiters).
   * Never rounds. The gem's `Amount.parse_ui`.
   *
   * @throws AmountError INVALID_INPUT, UNKNOWN_TYPE, UNKNOWN_LOCALE
   */
  parseUi(input: string, symbol: string, options: AmountsParseUiOptions = {}): Amount {
    const entry = this.registry.lookup(symbol);
    const locale = this.localeFor(options.locale);
    const parser = new UiParser(input, entry, locale);
    const atomic = parser.parse();

    return new Amount(this, entry, atomic);
  }

  /**
   * Reads the payload `toHash` writes. The gem's `Amount.load`.
   *
   * @throws AmountError INVALID_INPUT, UNKNOWN_TYPE
   */
  load(payload: AmountHash): Amount {
    if (typeof payload !== "object" || payload === null) {
      throw errors.invalidPayload("amount payload must be an object");
    }

    const version = payload.v;

    if (version !== undefined && version !== null && version !== SERIALIZATION_VERSION) {
      throw errors.invalidPayload(`unsupported amount serialization version: ${String(version)}`);
    }

    if (payload.atomic === undefined)
      throw errors.invalidPayload("amount payload missing key: atomic");

    if (payload.symbol === undefined)
      throw errors.invalidPayload("amount payload missing key: symbol");

    return this.of(payload.symbol, payload.atomic, { from: "atomic" });
  }

  /**
   * The locale table a call uses: the given locale, else the client's,
   * else `null` for plain output.
   *
   * @throws AmountError UNKNOWN_LOCALE
   */
  localeFor(explicit: string | null | undefined): Locale | null {
    const name = explicit ?? this.locale;

    return name === null ? null : this.registry.locale(name);
  }
}

function inferFormat(value: unknown): AmountInputFormat {
  if (typeof value === "bigint") return "atomic";

  if (typeof value === "string" || typeof value === "number") return "ui";

  throw errors.cannotInfer(value);
}

function readValue(value: AmountInput, format: AmountInputFormat, entry: RegistryEntry): bigint {
  if (format === "atomic") return readAtomic(value);

  if (format === "ui") return readUi(value, entry);

  throw errors.unknownFormat(format);
}

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
