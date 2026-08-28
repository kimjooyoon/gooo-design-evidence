# RFC: Gooo Design Release Review Packet v1

Status: Experimental. Only immutable release evidence and GitHub Actions determine conformance.

## User path

A design-system maintainer can submit one explicit Button review request and receive two generated artifacts:

1. `design-review-packet.json` for deterministic tools.
2. `design-review-packet.md` for a human reviewer.

The packet answers which released design-code relations are preserved, which reviewed exception remains intentional, which historical claim tuples were resolved, and whether the packet is publishable. It does not edit tokens, source code, Figma, or another repository.

## Metaprogramming boundary

`examples/design-review-packet/main.gooo` is the authority for all fifteen conformance activities and all five active decision tuples. The released Gooo v0.3 compiler checks the source, emits its activity graph, and resolves CLOSED, UNKNOWN, and three REFUTED outcomes from Gooo value programs. Shell code may validate and project released evidence, but it cannot invent or replace those claim tuples.

The inputs are exactly three immutable releases:

- Gooo core v0.3.0-dev.
- Design matcher v0.5.0-dev.
- Design claim-resolution adoption v0.6.0-dev.

## Fixed denominator and indicators

The denominator contains exactly fifteen cells. FOUNDATION, COHERENCE, and REGRESSION each own 5/15. DRIVER, OUTCOME, and GUARDRAIL each own 5/15.

Normal conformance records exact counts rather than an inferred score:

- Release inputs: 3/3.
- Review requests: 1/1.
- Relation dispositions: 4/4.
- Released claim tuples: 4/4 and 24/24 fields.
- Gooo decision receipts: 5/5 and 30/30 fields.
- Generated user artifacts: 2/2.
- Counterexamples: 4/4.
- Packet replay comparisons: 2/2.
- Repository writes, local tests, and cross-project required gates: 0/0/0.

Repository inventory excludes the root `README.md` and reports every Go and Gooo file with its physical line count.

## Resolution loss

The packet lowers resolution instead of guessing:

- A missing released matcher report yields 10 CLOSED / 5 UNKNOWN. The direct cell records `RELEASE_EVIDENCE`, `OBSERVE_RELEASED_MATCHER_EVIDENCE`, `MATCHER_RELEASE_REPORT_UNAVAILABLE`, `DIRECT_MISSING`, and `RESTORE_MATCHER_RELEASE_REPORT`. Four dependent cells record `DEPENDENCY_BLOCKED`.
- A changed released claim tuple yields 11 CLOSED / 4 REFUTED.
- An unreviewed mismatch yields 11 CLOSED / 4 REFUTED.
- Automatic-merge authority escalation yields 13 CLOSED / 2 REFUTED.

Removing any declared Gooo activity rejects generation before evidence projection.

## Independence

The normal result authorizes publication of an immutable review artifact, not an automatic merge. Outputs are written only to the Actions temporary directory. This repository releases independently; Link may observe the release later but cannot gate it.
