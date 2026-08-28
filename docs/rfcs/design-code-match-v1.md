# RFC: Gooo Design-Code Relation Matcher v1

Status: Experimental; only CI evidence determines conformance.

## Decision

The matcher answers one narrow question:

> Which explicit design-to-code relations are MATCH, UNKNOWN, or MISMATCH,
> and what evidence resolves the aggregate claim?

It consumes the existing Button fixture. It does not generate tokens, call a
live Figma API, infer semantic equivalence, compare pixels, or match names by
similarity.

## Relation state and claim state

Relation state and aggregate claim state are distinct:

- `MATCH` means all required explicit evidence coordinates are present.
- `UNKNOWN` means required evidence is absent and preserves stage, step,
  reason, unknown class, and next operation.
- `MISMATCH` means observed values or references differ.
- A reviewed, owned, scoped, and unexpired MISMATCH is known evidence and may
  coexist with a CLOSED aggregate claim.
- An unresolved MISMATCH refutes the aggregate claim.

State precedence for the aggregate claim remains `REFUTED > UNKNOWN > CLOSED`.

## Canonical Button relations

The normal fixture emits exactly four sorted relations:

| Relation | State | Resolution |
|---|---|---|
| Figma Variant to `ButtonProps.variant` | MATCH | explicit Code Connect, lineage, and source binding |
| Figma Disabled to `ButtonProps.disabled` | MATCH | explicit Code Connect, lineage, and source binding |
| DTCG `color.action` to `Button.background` | MATCH | token, CSS, lineage, and code-use chain |
| DTCG button radius to iOS radius | MISMATCH | reviewed intentional difference |

The aggregate normal result is therefore MATCH 3, MISMATCH 1, UNKNOWN 0,
reviewed mismatches 1, and unresolved mismatches 0.

## Counterexamples

- Removing the Disabled Code Connect property produces UNKNOWN with reason
  `CODE_CONNECT_PROPERTY_UNAVAILABLE`.
- Keeping names and source properties while removing the explicit Variant
  lineage edge produces UNKNOWN with reason `NAME_ONLY_MATCH_FORBIDDEN`.
- Changing `{color.blue}` to the missing alias `{color.missing}` produces an
  unresolved MISMATCH and aggregate REFUTED with reason
  `DTCG_ALIAS_TARGET_MISSING`.

No fallback may convert these states into MATCH.

## Fixed denominator

The denominator has exactly twelve cells. FOUNDATION, COHERENCE, and
REGRESSION each own 4/12. DRIVER, OUTCOME, and GUARDRAIL each own 4/12. Every
cell has one Gooo activity in `examples/design-code-match/main.gooo`; missing
or duplicated activities fail before relation evaluation.

## Effects and independence

Inputs are the released Gooo binary plus local versioned fixture files.
Outputs are written outside the input repository. Repository writes and
required cross-project gates are both zero. The absence of a live Figma
credential is not an error and is not a hidden gate.

The matcher may release independently. A downstream Link observation is
optional and cannot gate this repository or core.
