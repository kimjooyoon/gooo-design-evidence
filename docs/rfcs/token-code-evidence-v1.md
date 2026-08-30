# RFC: Token and Code Evidence v1

Status: Experimental; GitHub Actions is the only conformance environment.

## Decision

The `token-code-evidence` example answers one narrow question:

> Do explicit design-token values and references agree with explicit service
> and component code bindings?

The product reads DTCG JSON, generated CSS, a service, a component, an
explicit binding ledger, and the released Gooo semantic graph. It never
infers a relation from names, guesses design intent, repairs an input, or
writes to the repository. The JSON evidence and Markdown dossier are written
only beneath the caller-owned Actions temporary directory.

`examples/token-code-evidence/main.gooo` is the semantic authority. Its
released `gooo-graph/v1` graph must contain the same twelve activity names as
the fixed denominator, exactly once each. Go is present only as the Actions
Go 1.27 observation and as the released compiler's generated runtime; no
hand-authored Go implementation or local test execution is part of this
product.

## Fixed denominator

The denominator contains exactly twelve cells and twelve Gooo activities.
FOUNDATION, COHERENCE, and REGRESSION each contain four cells. DRIVER,
OUTCOME, and GUARDRAIL each contain four cells.

The normal fixture contains three tokens and four code bindings:

- `Button.tone=Brand` to `ButtonProps.tone=brand`;
- `/color/action` to `Button.background=var(--color-action)`;
- `/color/action` to `ButtonContract.actionToken=color.action`;
- `/space/control` to `Button.padding=var(--space-control)`.

The comparison is explicit values and references only. A valid digest is
evidence of bytes, not evidence of semantic agreement.

## Minimum cases

The CI job creates isolated, temporary copies of the fixture and proves:

| Case | Result | Boundary |
|---|---|---|
| exact match | CLOSED | all four explicit bindings agree |
| missing mapping | UNKNOWN | the binding is absent; names do not substitute for it |
| stale token | UNKNOWN | generated token output is missing/stale |
| explicit value contradiction | REFUTED | code value/reference differs from the declared binding |
| digest-valid laundering | REFUTED | a changed file has a newly valid digest but still contradicts semantics |
| mixed | REFUTED | one UNKNOWN plus one REFUTED resolves by `REFUTED > UNKNOWN > CLOSED` |
| authority escalation | REFUTED | read-only or output-scope authority is widened |

Every UNKNOWN preserves `stage`, `step`, `reason`, `unknown_class`,
`next_operation`, and `blocked_by`. REFUTED is never downgraded by a digest,
name similarity, or a neighboring UNKNOWN.

## Report contract

Each scenario emits `evidence.json` and `dossier.md`. Machine evidence
includes `token_count`, `code_binding_count`, `exact_matches`,
`unknown_bindings`, `refuted_bindings`, `generated_artifact_files`, peak RSS,
wall time, and an inventory of input files, directories, physical lines, Go
lines, and Gooo lines. The inventory explicitly excludes the repository root
`README.md`.

The runtime guardrails remain `repository_writes=0`,
`local_test_executions=0`, and `cross_project_required_gates=0`.
