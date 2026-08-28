# RFC: Independent evidence-generator consumer 2

## Decision

Consume the released `gooo-evidence-generator v0.2.3-dev` portable bundle in a
parallel GitHub Actions workflow. Existing design-evidence evaluation, Gooo
source, design fixtures, CI, and root README remain unchanged.

## Distinct domain

This consumer binds design tokens, Code Connect properties, code-token lineage,
intentional differences, and evidence-graph activities. It shares no domain
activity names with the local-ledger consumer. The common generated contract is
therefore the generator meta graph and promotion policy, not copied business
semantics.

## Core-lock preservation

The design consumer's valid core lock nests tag, tag-object, target, and eight
assets under `release`, with runtime archive selection under `runtime`. The
generator must preserve that complete structure and may not introduce a flat
top-level `assets` field.

## Exact denominator

- domain activities: `12`;
- generated cells: `12`;
- required promoted patterns: `11`;
- generated files: `7`;
- manifest-covered files: `6`;
- root README readiness authority: `0`;
- source repository writes: `0`;
- local test executions: `0`.

## Adversarial cases

- remove `ObserveDesignSourceBundle`: `3 CLOSED + 1 DIRECT_MISSING + 8
  DEPENDENCY_BLOCKED`;
- duplicate `EvaluateEvidenceGraph`: `8 CLOSED + 4 REFUTED`;
- mutate a generated denominator: `5/6 VERIFIED + 1 REFUTED`.

Project-graph mutations must leave promoted generator patterns at `11`.

## Completion boundary

This repository becomes independent public consumer `2/2` only after merge and
main-branch CI. That closes generator external validity, not language
self-improvement; selecting and releasing a core change remains a later gate.
