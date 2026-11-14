/**
 * Every error the client raises is created here.
 *
 * Each factory owns the message for one failure mode, worded as the gem
 * words it, and every error carries a machine-readable `code` naming the
 * gem exception it stands for (specs/03-interface.md#errors). Callers
 * `throw errors.<name>(...)` and never build error strings themselves.
 */

/**
 * Machine-readable code, one per gem exception the client mirrors:
 *
 * | Code | Gem | Raised when |
 * | --- | --- | --- |
 * | `TYPE_MISMATCH` | `Amount::TypeMismatch` | cross-type math without a default rate; a non-scalar operand |
 * | `INVALID_INPUT` | `Amount::InvalidInput` | a value, compact string, typed input or payload can't be read |
 * | `UNKNOWN_TYPE` | `Registry::UnknownType` | a symbol the manifest doesn't register |
 * | `NO_DEFAULT_RATE` | `Registry::NoDefaultRate` | `to` without a rate, and none registered |
 * | `INVALID_DISPLAY_UNIT` | `Registry::InvalidDisplayUnit` | a display unit the type doesn't have |
 * | `ZERO_DIVISION` | `ZeroDivisionError` | dividing by zero |
 * | `INVALID_ARGUMENT` | `ArgumentError` | bad `split`, `allocate` or `compact` arguments |
 * | `NOT_COMPARABLE` | `ArgumentError` from `Comparable` | `lessThan` and friends across unrelated types |
 * | `UNKNOWN_LOCALE` | `I18n::InvalidLocale` | a locale the manifest wasn't exported with |
 * | `INVALID_MANIFEST` | — | `fromManifest` on a malformed manifest |
 */
export type AmountErrorCode =
  | "TYPE_MISMATCH"
  | "INVALID_INPUT"
  | "UNKNOWN_TYPE"
  | "NO_DEFAULT_RATE"
  | "INVALID_DISPLAY_UNIT"
  | "ZERO_DIVISION"
  | "INVALID_ARGUMENT"
  | "NOT_COMPARABLE"
  | "UNKNOWN_LOCALE"
  | "INVALID_MANIFEST";

/**
 * The one error class the client throws. Branch on `code`, never on the
 * message: messages follow the gem's wording and can change; codes don't.
 *
 * @example Validating a form field
 *   try {
 *     return { amount: amounts.parseUi(input, "USD", { locale }) };
 *   } catch (error) {
 *     if (error instanceof AmountError && error.code === "INVALID_INPUT") {
 *       return { error: "Enter an amount like 12.50" };
 *     }
 *     throw error;
 *   }
 */
export class AmountError extends Error {
  /** Which failure this is; see {@link AmountErrorCode}. */
  readonly code: AmountErrorCode;

  /**
   * @param code - the failure mode
   * @param message - a human-readable message, worded as the gem words it
   */
  constructor(code: AmountErrorCode, message: string) {
    super(message);
    this.name = "AmountError";
    this.code = code;
  }
}

/** A value as it appears in an error message: strings quoted, as Ruby's `inspect`. */
function describe(value: unknown): string {
  if (typeof value === "string") return JSON.stringify(value);

  if (typeof value === "bigint") return value.toString();

  return String(value);
}

/** The factories, one per failure mode. */
export const errors = {
  typeMismatch(symbol: string, other: string): AmountError {
    return new AmountError("TYPE_MISMATCH", `type mismatch: ${symbol} vs ${other}`);
  },

  notScalar(kind: string): AmountError {
    return new AmountError("TYPE_MISMATCH", `expected scalar, got ${kind}`);
  },

  cannotParse(input: unknown, symbol?: string): AmountError {
    const target = symbol === undefined ? "" : ` as ${symbol}`;

    return new AmountError("INVALID_INPUT", `cannot parse ${describe(input)}${target}`);
  },

  cannotParseUi(input: unknown, symbol: string, reason: string): AmountError {
    return new AmountError(
      "INVALID_INPUT",
      `cannot parse ${describe(input)} as ${symbol}: ${reason}`,
    );
  },

  cannotInfer(value: unknown): AmountError {
    return new AmountError("INVALID_INPUT", `cannot infer type for ${typeof value}`);
  },

  unknownFormat(format: unknown): AmountError {
    return new AmountError("INVALID_INPUT", `unknown amount format: ${describe(format)}`);
  },

  invalidPayload(reason: string): AmountError {
    return new AmountError("INVALID_INPUT", reason);
  },

  unknownType(symbol: string): AmountError {
    return new AmountError("UNKNOWN_TYPE", `${symbol} is not registered`);
  },

  noDefaultRate(from: string, to: string): AmountError {
    return new AmountError(
      "NO_DEFAULT_RATE",
      `no default rate for ${from} -> ${to}; pass rate: explicitly`,
    );
  },

  noDisplayUnits(symbol: string): AmountError {
    return new AmountError("INVALID_DISPLAY_UNIT", `${symbol} has no display_units configured`);
  },

  unknownDisplayUnit(unit: string, symbol: string): AmountError {
    return new AmountError("INVALID_DISPLAY_UNIT", `unknown display unit ${unit} for ${symbol}`);
  },

  zeroDivision(): AmountError {
    return new AmountError("ZERO_DIVISION", "divided by 0");
  },

  invalidArgument(message: string): AmountError {
    return new AmountError("INVALID_ARGUMENT", message);
  },

  invalidCompactOption(option: unknown): AmountError {
    return new AmountError(
      "INVALID_ARGUMENT",
      `compact: must be true, false or { precision: Integer }, got ${describe(option)}`,
    );
  },

  invalidCompactPrecision(digits: unknown): AmountError {
    return new AmountError(
      "INVALID_ARGUMENT",
      `compact: precision must be a positive Integer, got ${describe(digits)}`,
    );
  },

  notComparable(other: string): AmountError {
    return new AmountError("NOT_COMPARABLE", `comparison of Amount with ${other} failed`);
  },

  unknownLocale(locale: string): AmountError {
    return new AmountError("UNKNOWN_LOCALE", `the manifest has no locale ${describe(locale)}`);
  },

  invalidManifest(path: string, expectation: string): AmountError {
    return new AmountError("INVALID_MANIFEST", `invalid manifest: ${path} must be ${expectation}`);
  },
};
