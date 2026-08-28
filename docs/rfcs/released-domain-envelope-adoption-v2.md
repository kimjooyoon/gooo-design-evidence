# Released-domain envelope v2 adoption candidate

## Decision

This repository adds one product-owned adoption candidate for the released
Design Evidence domain. It consumes the immutable v0.7.0-dev Design Evidence
review packet and the v0.3.0-dev interchange consumer kit. It does not create a
new connector, generate design or application code, or claim that the product
has released or that an external user found utility.

The generator is driven by the released Gooo core's twelve activity
cardinality receipts and by the released Design Evidence packet. A source
digest, name-only match, or generated value is not promoted to semantic truth.
The eight-file output is written only to caller-owned temporary output.

## Fixed denominator

The product keeps exactly twelve cells and twelve one-to-one Design Evidence
Gooo activities:

- FOUNDATION: `CORE_RELEASE`, `SPEC_RELEASE`, `DESIGN_RELEASE`, and
  `META_ACTIVITY_AUTHORITY`.
- COHERENCE: `CLAIM_DISPOSITION_SOURCE`, `PRODUCT_PROJECTION`,
  `EIGHT_FILE_ENVELOPE`, and `READ_ONLY_CONFORMANCE`.
- REGRESSION: `UNKNOWN_CAUSALITY`, `DETERMINISTIC_REPLAY`,
  `REFUTED_COUNTEREXAMPLES`, and `AUTHORITY_BOUNDARY`.

The generic denominator shipped inside the immutable consumer kit is observed
only by that kit's conformer; it is not copied into or used as this product's
denominator. The product denominator's `DRIVER`, `OUTCOME`, and `GUARDRAIL`
indicator classes are four cells each.

Each proof class is 4/4. A dependency failure is represented as
`DEPENDENCY_BLOCKED` with a stable `blocked_by`
frontier; a directly missing fact is `DIRECT_MISSING` with an empty frontier.
Each UNKNOWN retains `stage`, `step`, `reason`, `unknown_class`,
`next_operation`, and `blocked_by`. A known contradiction is `REFUTED` and
has precedence over UNKNOWN. An unrecognized Core decision, including
`FIXED_POINT`, fails closed.

## Product projection

The released packet owns four relation-disposition rows and four claim tuples.
The candidate projects the four disposition rows into:

- four `relations.ndjson` rows;
- four `evidence.ndjson` anchors to the immutable packet asset and JSON
  pointers;
- four `resolutions.ndjson` rows, with the six coordinates preserved for any
  UNKNOWN row;
- the existing four claim tuples retained in `project.json` as source-owned
  ledger evidence.

The envelope is exactly:
`project.json`, `evidence.ndjson`, `relations.ndjson`, `resolutions.ndjson`,
`unknowns.ndjson`, `replay.json`, `conformance.json`, and `checksums.txt`.
The PR workflow downloads the kit asset by release asset ID, verifies its
size and SHA-256 digest, and executes the kit's read-only conformer. It does
not check out the interchange specification repository or copy its conformer.

## Adoption and utility boundaries

The candidate reports released adoption as `0/1 UNKNOWN` because this PR is
not an immutable product release. External utility is `0/1 UNKNOWN` because no
independent user validation is present. No improvement claim is made: the
exact before/after pair count is `0/1 UNKNOWN`.

The workflow has no cross-project required gate, does not make Interchange CI
a required status, and does not merge or publish a release. The root README
is excluded from inventory. It reports Go/Gooo file counts and physical lines,
descendant directories, general files, peak RSS KiB, wall milliseconds,
repository writes, and local test executions.

## Minimum examples

The PR exercises one normal CLOSED candidate, two valid UNKNOWN coordinate
classes (`DIRECT_MISSING` and `DEPENDENCY_BLOCKED`), and five invalid-envelope
counterexamples that must fail closed. These are conformance examples, not
external utility evidence.
