/**
 * Display templates, in the style of Rails' `number.currency.format.format`:
 * `%n` is the formatted number (sign included) and `%u` the unit label.
 * Everything else is copied as given. The gem's `Amount::Formattable`
 * module functions, mirrored.
 */

export const NUMBER = "%n";
export const LABEL = "%u";

const PLACEHOLDER = /%[nu]/g;

/**
 * Whether a value is a usable template: a string that places the number.
 * The gem's `Formattable.valid_template?`; a locale template without `%n`
 * is ignored so a typo can't drop the amount from the output.
 *
 * @example
 *   isValidTemplate("%n %u");  // true
 *   isValidTemplate("%u");     // false
 */
export function isValidTemplate(template: unknown): template is string {
  return typeof template === "string" && template.includes(NUMBER);
}

/**
 * Fills a template in one pass — the gem's `Formattable.fill` — so a `%`
 * inside the number or label is never read as a placeholder. Everything
 * else in the template, a non-breaking space included, is copied as given.
 *
 * @param template - a template containing `%n` and usually `%u`
 * @param number - the formatted number, sign included
 * @param label - the unit label
 *
 * @example
 *   fillTemplate("%u%n", "1.50", "$");    // "$1.50"
 *   fillTemplate("%n %u", "12,50", "€");  // "12,50 €"
 */
export function fillTemplate(template: string, number: string, label: string): string {
  return template.replace(PLACEHOLDER, (placeholder) => {
    return placeholder === NUMBER ? number : label;
  });
}
