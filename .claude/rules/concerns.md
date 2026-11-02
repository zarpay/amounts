---
paths:
  - "gem/lib/**/*.rb"
---

# Concerns: keep `Amount` thin

`gem/lib/amount.rb` holds only an amount's identity: the error classes, `atomic`,
`symbol`, `registry_entry`, `decimals`, `decimal`, `initialize`, `inspect`, the
`include` list and the display delegators. **Don't add behavior to that file.** New
behavior goes in a concern, an existing one or a new one.

## Where things go

| Kind | Location | Constant | Example |
|---|---|---|---|
| Concern: a module mixed into `Amount` | `gem/lib/amount/concerns/<name>.rb` | `Amount::<Name>` | `Amount::Calculable` |
| Collaborator: a class or module `Amount` *uses* | `gem/lib/amount/<name>.rb` | `Amount::<Name>` | `Amount::Display`, `Amount::UiParser` |
| ActiveRecord adapter | `gem/lib/amount/active_record/` | `Amount::ActiveRecord::<Name>` | `Amount::ActiveRecord::Type` |

`concerns/` is a folder, not a namespace (like Rails' `app/models/concerns`). A concern
in `concerns/calculable.rb` is `Amount::Calculable`, never `Amount::Concerns::Calculable`.
Concern constants aren't documented as public API, so the documented surface is
`Amount`'s methods, not which concern holds them. Still give a rename a CHANGELOG entry.

Name every concern as an *-able* / *-ible* adjective for what it makes an amount:
`Calculable`, `Convertible`, `Formattable`, `Parsable`, `Serializable`. The
`Amounts/ConcernNaming` cop enforces this. Don't reuse the name of a Ruby core module
(`Comparable`, `Enumerable`, `Kernel`, ...): inside `Amount` and its subclasses, a bare
`Comparable` would then mean `Amount::Comparable`. That's why the comparison concern is
`Orderable`.

One capability per concern. If its doc comment needs "and" to say what it does, it is
probably two concerns.

## Loading

All core loading happens in `gem/lib/amount.rb`, in dependency order. Core files under
`gem/lib/amount/` never `require_relative` each other. The only other entry points are
the documented optional adapters: `amount/active_record`, `amount/rspec` and
`amount/active_record/rspec`. Each of these loads its own files.

When a file moves, update its line in `gem/lib/amount.rb`. Don't leave a pointer file
at the old path (a file whose only job is to `require_relative` the new location).

## Shape of a concern

The core is Rails-agnostic, so a concern is a plain Ruby module, not
`ActiveSupport::Concern`. Every concern follows the same shape:

```ruby
# frozen_string_literal: true

class Amount
  # Concern: <one line on what it owns>.
  #
  # <rules and invariants it keeps>
  module Example
    SOME_CONSTANT = 1 # constants it owns

    def self.included(base) # only when it has class-level methods
      base.extend(ClassMethods)
    end

    # Class-level methods extended onto any class that does `include Example`.
    module ClassMethods
      # YARD docs with @param / @return / @example
      def something; end
    end

    # Stateless helpers other parts of the gem share, as `self.` methods.
    def self.helper(value); end

    # Public instance methods, each with YARD docs.
    def example_method; end

    private

    # Private helpers this concern needs.
  end
end
```

- Add `include Example` to `Amount` and `require_relative "amount/concerns/example"`
  under the concerns block in `gem/lib/amount.rb`, then list it in the class doc
  comment there.
- A concern relies on `Amount`'s public surface (`atomic`, `symbol`, `registry_entry`,
  `decimal`, ...) and on private helpers documented as shared: `build` (in
  `Constructible`) and `ensure_same_type!` / `coerce_other_to_self_type(!)` (in
  `Coercible`). Don't reach into another concern's other private methods.
- Class-level state lives on `Amount` itself (`Amount.instance_variable_get(:@registry)`),
  not on `self`, so subclasses registered with `class:` share it.
- A concern gets its own test file: `gem/test/amount/concerns/<name>_test.rb` (see
  `tests.md`).

## Collaborators that grow

The same rule applies below `Amount`: when a collaborator such as `Display` or
`Registry` picks up a second responsibility, split it out instead of adding another
option branch.
