# Generator v0.3 core receipt consumer

## Decision

The design evidence project adds a parallel read-only conformance path that consumes immutable Gooo v0.2.0-dev and evidence-generator v0.3.1-dev release assets. Existing v0.1 readiness and generator v0.2.3 paths remain unchanged.

This path does not claim compatibility with every Gooo v0.2 capability.

## Product-shaped closure

The user-visible result is a generated design-to-code semantic evidence bundle. It answers whether the declared design source, token claim, Code Connect mapping, code-token lineage, intentional difference, and evidence graph are supported by exact released-core Activity receipts.

It does not transform tokens, publish to Figma, rename code, or perform pixel comparison.

## Fixed completion units

The first release has 6 completion units:

| Unit | Closed only when |
|---|---|
| Immutable tools | Both public release archives match pinned SHA-256 values |
| Source semantics | Released Gooo accepts the actual v0.2 design model and emits its semantic graph |
| Activity receipts | 11/11 meta receipts and 12/12 design receipts are CLOSED |
| Generated evidence | 12/12 cells close and 6/6 generated files verify |
| Degraded resolution | Four adversarial states expose exact stage, step, reason, and next operation |
| Non-mutation | Replay is byte-identical, repository writes are 0, and local tests are 0 |

## Denominators

Proof choices are FOUNDATION 4, COHERENCE 5, and REGRESSION 3.

Indicator classes are OUTCOME 3, DRIVER 5, and GUARDRAIL 4.

Exactly one cell declares core_identity_anchor: GOOO_RELEASE_IDENTITY. The generator never recognizes that cell by ID or Activity name. A release mismatch refutes the declared role and propagates only through the design-owned dependency graph.

## Expected states

| Scenario | CLOSED | UNKNOWN | REFUTED |
|---|---:|---:|---:|
| Complete | 12 | 0 | 0 |
| Missing DESIGN_SOURCE_BUNDLE receipt | 3 | 9 | 0 |
| Invalid DESIGN_SOURCE_BUNDLE decision | 3 | 0 | 9 |
| Ambiguous EVIDENCE_GRAPH selector | 8 | 0 | 4 |
| Core identity mismatch | 2 | 0 | 10 |
| Missing identity anchor | 0 | 0 | 12 |

An absent receipt lowers resolution to UNKNOWN. An unrecognized decision such as FIXED_POINT is REFUTED. A selector widened to the designevidence namespace uses valid source and produces an actual ambiguous core receipt.

## Independence

The repository consumes public release bytes only. It does not import producer packages, check out producer branches, or require producer CI to run. All generated files are written to runner temporary storage. A failed experimental path does not change the existing v0.1 readiness decision.

## Deferred work

Private Figma files, authenticated Figma APIs, write-back, visual diff, fuzzy names, automatic renames, and deployment are outside the denominator. A future connector may consume this release receipt, but it cannot become a predecessor until the same relation is observed in at least one additional independent domain.
