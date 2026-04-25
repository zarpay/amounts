# Design Decisions

This gem is opinionated. Those opinions are part of its value.

## Atomic integers, not decimal storage

The atomic value is always an integer count of the smallest unit. That keeps equality, hashing, and persistence crisp.

## One class, registry-driven types

Type identity lives in the registry because adding a new symbol should be a configuration action, not a subclass ceremony.

## Directional rates only

Rates are directional because real conversion systems are directional.

## Display units are not conversions

Showing gold in grams is still showing gold. The type has not changed.

## Explicit remainder

`split` and `allocate` return remainder explicitly because silent distribution bakes in a business preference.

## Lockable global registry

The global registry is a practical boot-time configuration surface. `lock!` exists so the convenience of a shared registry does not imply ongoing runtime mutability.
