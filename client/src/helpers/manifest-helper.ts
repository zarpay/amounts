/**
 * Readers for an untrusted manifest. Each takes a value and the path it
 * was found at, and returns it typed or throws `INVALID_MANIFEST` naming
 * that path — so a model built from the manifest never re-checks a field.
 *
 * Absence and invalidity differ: a reader for an optional field accepts
 * `null`, never a missing key, because the gem writes every key.
 */

import type { Label } from "@/types.js";

import { parseDecimal } from "@/helpers/decimal-helper.js";
import { errors } from "@/helpers/errors-helper.js";
import { isValidTemplate } from "@/helpers/template-helper.js";

/** A plain object (not an array, not `null`). */
export function readRecord(value: unknown, path: string): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw errors.invalidManifest(path, "an object");
  }

  return value as Record<string, unknown>;
}

/** An array. */
export function readArray(value: unknown, path: string): unknown[] {
  if (!Array.isArray(value)) throw errors.invalidManifest(path, "an array");

  return value;
}

/** A non-negative integer. */
export function readCount(value: unknown, path: string): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0) {
    throw errors.invalidManifest(path, "a non-negative integer");
  }

  return value;
}

/** A string. */
export function readString(value: unknown, path: string): string {
  if (typeof value !== "string") throw errors.invalidManifest(path, "a string");

  return value;
}

/** `true` or `false`. */
export function readBoolean(value: unknown, path: string): boolean {
  if (typeof value !== "boolean") throw errors.invalidManifest(path, "a boolean");

  return value;
}

/** An exact decimal string, as the gem writes a rate or scale. */
export function readDecimal(value: unknown, path: string): string {
  if (typeof value !== "string" || parseDecimal(value) === null) {
    throw errors.invalidManifest(path, "a decimal string");
  }

  return value;
}

/** A template that places the number (`%n`). */
export function readTemplate(value: unknown, path: string): string {
  if (!isValidTemplate(value)) throw errors.invalidManifest(path, "a template containing %n");

  return value;
}

/** A label: a string, or plural forms mapping each key to a string. */
export function readLabel(value: unknown, path: string): Label {
  if (typeof value === "string") return value;

  const forms = readRecord(value, path);
  const invalid = Object.values(forms).some((form) => typeof form !== "string");

  if (invalid) throw errors.invalidManifest(path, "a string or an object of strings");

  return Object.freeze({ ...(forms as Record<string, string>) });
}

/** A type's `display_symbol`: a label whose plural forms include `other`, as the gem requires. */
export function readDisplaySymbol(value: unknown, path: string): Label {
  const label = readLabel(value, path);

  if (typeof label !== "string" && label["other"] === undefined) {
    throw errors.invalidManifest(path, "a string or plural forms with an other key");
  }

  return label;
}

/** `null`, or what `read` reads. */
export function readNullable<T>(
  value: unknown,
  path: string,
  read: (value: unknown, path: string) => T,
): T | null {
  if (value === null) return null;

  return read(value, path);
}
