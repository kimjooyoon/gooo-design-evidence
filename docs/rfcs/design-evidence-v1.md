# Design evidence v1

## Decision

This repository observes design-to-code evidence. It is not a design-token
generator, a Figma synchronization service, a visual regression tool, or a
semantic equivalence prover.

The user-facing question is narrow:

> Which design claim is implemented by which code symbol, through which exact
> evidence, and where does the chain become unknown or contradicted?

## Authority order

1. The `.gooo` source declares the semantic activities and claim boundary.
2. The fixed denominator names the twelve observations required to close it.
3. DTCG, parsed Code Connect, source code, generated outputs, and lineage files
   are external evidence.
4. The released Gooo CLI supplies version and syntax/diagnostic receipts.
5. The repository-owned evaluator reduces evidence to CLOSED, UNKNOWN, or
   REFUTED without claiming compiler-level cross-format semantics.

Generated files never become the authority merely because they compile or have
the same final value as a token.

## Munchausen proof choices

The denominator is exactly `FOUNDATION 4 + COHERENCE 5 + REGRESSION 3 = 12`.
These are proof choices, not weights.

- FOUNDATION fixes public identity, release identity, source bytes, and the
  released compiler receipt.
- COHERENCE checks explicit relationships among design, generated output, and
  code.
- REGRESSION checks zero write, replay, and preservation of adverse states.

No cell can be added to the denominator by discovering more files at runtime.
A denominator change requires a versioned contract change.

## State reduction

State precedence is deterministic:

```text
REFUTED > UNKNOWN > CLOSED
```

`UNKNOWN` always includes stage, step, reason, and next operation. A downstream
cell blocked by an unknown or refuted dependency does not invent a direct
failure. It records dependency blocking separately.

The normal first observation deliberately leaves replay and predecessor trace
unknown. The final observation may close them only by consuming the exact first
report digest and claim coordinates.

## Read-only release boundary

The consumer owns a complete lock for one public prerelease. CI verifies the
annotated tag object, target commit, all eight release assets, sizes, GitHub
digests, and `SHA256SUMS`. It downloads only the Linux CLI archive and checksum
index into runner temporary storage.

Forbidden fallbacks include:

- importing a core Go package;
- checking out a core branch;
- using a `go.mod` replacement;
- building or installing the compiler from source;
- treating a missing or unknown schema as success.

All reports, counterexample fixtures, extracted executables, and replay outputs
are written outside the input repository. CI compares exact pre/post repository
snapshots.

## Fixture boundary

The first fixture is intentionally synthetic. A private Figma file would add
authentication, availability, mutable remote state, and disclosure concerns
before the semantic model is proven. Live Figma evidence can be added later as
an optional claim; its absence must not block the public fixture.

The evaluator must not infer meaning from:

- equal colors or dimensions;
- similar token or property names;
- a Code Connect URL without a source binding;
- generated output without a lineage edge;
- visual pixel similarity;
- AI confidence.

An intentional difference closes only when its scope, reason, owner, reviewer,
and unexpired review boundary are explicit.

## Extraction rule

This project does not define a universal ecosystem protocol. After two distinct
public consumers close their own vertical slices, only fields proven common to
both may be proposed for `gooo/link/v1`. Until then, the design evidence schema
belongs to this repository and cannot block the core release cadence.
