# RFC: Claim Resolution Primitive Adoption v1

Status: Experimental; only CI evidence can select or refute adoption.

## Decision

Design Evidence independently consumes the released Gooo
`gooo.primitive.claim-resolution-tuple.v1` implementation. It does not copy the
core parser or import core Go packages. GitHub Actions invokes the released
`gooo claim resolve` command against a Design Evidence Gooo value program and
compares the resulting six-field claims with the immutable matcher v0.5
reports.

## Fixed observations

The adoption resolves four real matcher states:

- one CLOSED relation aggregate;
- one missing-Code-Connect UNKNOWN with `DIRECT_MISSING`;
- one name-only-evidence UNKNOWN with `DIRECT_MISSING`;
- one unresolved DTCG contradiction with REFUTED.

Two guard cases are also executed. An UNKNOWN without `unknown_class` must fail
closed with `UNKNOWN_TUPLE_INCOMPLETE`. An unrecognized `FIXED_POINT` state must
fail closed with `CLAIM_STATE_UNKNOWN`. Evidence is not accepted merely because
the command exits or emits JSON.

## Meta binding

The denominator has exactly twelve cells. Proof choices are FOUNDATION 4,
COHERENCE 4, and REGRESSION 4. Indicator classes are DRIVER 4, OUTCOME 4, and
GUARDRAIL 4. Every cell has exactly one activity in
`examples/claim-resolution-adoption/main.gooo`; the four claim scenarios and
two rejection scenarios are literal Gooo value programs interpreted by core.

## Authority boundary

- Core owns tuple parsing, allowed states, and boundary validation.
- Design Evidence owns which observed matcher scenario selects which activity.
- The v0.5 matcher reports remain immutable evidence.
- No dependency propagation, automatic repair, merge, or source mutation is
  authorized.
- A missing core receipt is UNKNOWN; a field mismatch or invalid core decision
  is REFUTED.

## Promotion meaning

Closing this adoption records one independent product consumer. It does not
prove all Design Evidence decisions use core, and it does not authorize a
common generator. The next operation is to publish the immutable adoption and
let Gooo Link observe a second direct primitive mapping.
