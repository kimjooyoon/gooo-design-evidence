# Gooo Design Evidence

Gooo Design Evidence is a read-only external consumer of the experimental Gooo
language. It evaluates whether design intent, generated tokens, and application
code are connected by explicit evidence rather than by matching names or final
values.

The repository does not import the Gooo compiler source. CI downloads the
digest-locked `v0.1.0-dev` executable and consumes only `version --json`,
syntax `check --json`, explicit `check --semantic --json`, and `graph dump`
receipts.

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
