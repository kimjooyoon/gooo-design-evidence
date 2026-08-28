# Gooo Design Evidence

Gooo Design Evidence is a read-only external consumer of the experimental Gooo
language. It evaluates whether design intent, generated tokens, and application
code are connected by explicit evidence rather than by matching names or final
values.

The repository does not import the Gooo compiler source. CI downloads the
digest-locked `v0.1.0-dev` executable and consumes only `version --json`,
syntax `check --json`, explicit `check --semantic --json`, and `graph dump`
receipts.

## Released-domain envelope v2 adoption candidate

The product-owned candidate in `examples/released-domain-envelope-v2/` binds
exactly twelve Gooo activities to the released-domain envelope v2 denominator.
Its PR workflow downloads the immutable v0.3.0-dev consumer kit by asset ID and
digest, projects the released Design Evidence v0.7.0-dev packet into eight
files, and runs the kit's read-only conformer. The candidate reports
product-owned projection 1/1, envelope files 8/8, relations/evidence/
resolutions 4/4/4, conformer checks 10/10, and deterministic replay 1/1.

Released adoption and external utility remain 0/1 UNKNOWN until a product
release and independent user evidence exist. The workflow has zero repository
writes, local test executions, and cross-project required gates; generated
output is caller-owned temporary output only. See
`docs/rfcs/released-domain-envelope-adoption-v2.md` for the boundary and
`contracts/released-domain-envelope-denominator-v2.json` for the fixed cells.

## First vertical slice

The synthetic `Button` fixture contains:

- three DTCG 2025.10 tokens;
- one parsed Code Connect observation with two required property mappings;
- one TypeScript component;
- CSS and iOS token outputs;
- nine explicit lineage edges;
- one reviewed, expiring platform difference;
- one `.gooo` authority projection with twelve evaluation activities.

No Figma account, cloud credential, private source, or live API is required.
The fixture is deliberately small enough for every success claim to have an
exact denominator.

## Human-facing CI result

A successful run reports exactly:

```text
design evidence closure     12/12
FOUNDATION                    4/4
COHERENCE                     5/5
REGRESSION                    3/3
property mappings             2/2
token lineage                 3/3
intentional differences       1/1
UNKNOWN                       0/12
REFUTED                       0/12
repository writes             0
```

The first report is intentionally `10/12 CLOSED, 2/12 UNKNOWN`. The final
report consumes that predecessor and a deterministic replay to reach `12/12`.
CI also proves three counterexamples:

- a missing Code Connect property mapping remains `UNKNOWN` with a stage,
  step, reason, and next operation;
- a broken DTCG alias is `REFUTED`;
- a one-byte-equivalent release digest contradiction is `REFUTED` before any
  fallback can run.
- a URI-unsafe namespace accepted by syntax-only `check` and rejected by both
  explicit semantic check and graph lowering closes an exact command-resolution
  receipt.

## Authority and evidence

`examples/button-system/main.gooo` is the semantic authority for the twelve
activities. JSON, TypeScript, CSS, shell evaluation, and CI reports are
evidence or derived views. In v2, `gooo-graph/v1` binds the activity identity
set and exact source digest. Activity source spans are not exposed by that
schema and remain `NOT_AVAILABLE`; cross-format design semantics remain
`NOT_CLAIMED`.

See `docs/rfcs/design-evidence-v1.md` for the decision model and exclusions.
Read-only design-to-code semantic evidence evaluated with released Gooo

## Canonical relation matcher

The additive matcher vertical slice emits four deterministic relation tuples
for the same Button fixture. Three explicit implementation chains are MATCH.
The iOS radius difference remains MISMATCH but is closed by its reviewed,
owned, and expiring difference evidence. Missing Code Connect evidence and
name-only similarity remain typed UNKNOWN; a broken token alias is REFUTED.

Relation state and aggregate claim state are intentionally separate. A
reviewed MISMATCH can be known and closed, while an unresolved contradiction
cannot. All twelve matcher acceptance cells are declared in
`examples/design-code-match/main.gooo` and bound through the released Gooo
semantic graph.
