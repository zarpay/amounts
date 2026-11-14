import { errors } from "@/helpers/errors-helper.js";

/** The only compact-string version there is (`Parser::SUPPORTED_VERSION`). */
const SUPPORTED_VERSION = "v1";
/** An optional version prefix: `"v1:USDC|1.50"`. */
const VERSION_PREFIX = /^(v\d+):(.*)$/;

/**
 * Splits the compact string amounts travel in — the gem's
 * `Amount::Parser`.
 *
 * The format is a symbol, a bar and a value in whole units:
 * `"USDC|1.500000"`, as {@link Amount.toJSON} and the gem's `as_json`
 * write it. An explicit version prefix, `"v1:USDC|1.50"`, is accepted too;
 * any other version is refused, so a future format is never misread.
 *
 * It splits and nothing more: {@link Amounts.parse} reads the value as a
 * UI value, exactly as the gem hands it to `Amount.new`.
 *
 * Internal: use {@link Amounts.parse}.
 */
export class Parser {
  /** The symbol before the bar. */
  readonly symbol: string;
  /** Everything after the first bar, unread. */
  readonly value: string;

  private constructor(symbol: string, value: string) {
    this.symbol = symbol;
    this.value = value;
    Object.freeze(this);
  }

  /**
   * Splits a compact string into its symbol and value.
   *
   * @param input - `"SYMBOL|value"` or `"v1:SYMBOL|value"`
   * @throws {@link AmountError} `INVALID_INPUT` for an unsupported version,
   *   or unless both a symbol and a value are present
   *
   * @example
   *   Parser.parse("v1:USDC|1.50");  // { symbol: "USDC", value: "1.50" }
   */
  static parse(input: string): Parser {
    const compact = String(input);
    const body = unversioned(compact, input);
    const separator = body.indexOf("|");
    const symbol = separator === -1 ? body : body.slice(0, separator);
    const value = separator === -1 ? "" : body.slice(separator + 1);

    if (symbol === "" || value === "") throw errors.cannotParse(input);

    return new Parser(symbol, value);
  }
}

/** The string without its version prefix, refusing any version but `v1`. */
function unversioned(compact: string, input: string): string {
  const versioned = VERSION_PREFIX.exec(compact);

  if (!versioned) return compact;

  const [, version, body = ""] = versioned;

  if (version !== SUPPORTED_VERSION) throw errors.cannotParse(input);

  return body;
}
