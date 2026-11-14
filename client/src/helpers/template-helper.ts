/**
 * Display templates, in the style of Rails' `number.currency.format.format`:
 * `%n` is the formatted number (sign included) and `%u` the unit label.
 * Everything else is copied as given. The gem's `Amount::Formattable`
 * module functions, mirrored.
 */

export const NUMBER = "%n";
export const LABEL = "%u";

const PLACEHOLDER = /%[nu]/g;

/** A usable template is a string that places the number. */
export function isValidTemplate(template: unknown): template is string {
  return typeof template === "string" && template.includes(NUMBER);
}

/**
 * Fills a template in one pass, so a `%` inside the number or label is
 * never read as a placeholder.
 */
export function fillTemplate(template: string, number: string, label: string): string {
  return template.replace(PLACEHOLDER, (placeholder) => {
    return placeholder === NUMBER ? number : label;
  });
}
