#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 OUTPUT_DIRECTORY" >&2
  exit 64
fi

root=$(cd "$(dirname "$0")/.." && pwd)
output=$1
mkdir -p "$output"
output=$(cd "$output" && pwd)
work="$output/work"
mkdir -p "$work"

repository="kimjooyoon/gooo-design-evidence"
denominator="$root/contracts/design-evidence-denominator-v2.json"
base_lock="$root/contracts/core-release-lock-v2.json"
projection="$root/examples/button-system/main.gooo"
fixture="$root/fixtures/button-system"
subject_sha=$(git -C "$root" rev-parse HEAD)

digest_file() {
  printf 'sha256:%s' "$(sha256sum "$1" | cut -d' ' -f1)"
}

canonical_digest() {
  jq -S -c . "$1" | sha256sum | awk '{print "sha256:" $1}'
}

snapshot_repository() {
  (
    cd "$root"
    find . -path './.git' -prune -o -type f -print0 \
      | LC_ALL=C sort -z \
      | while IFS= read -r -d '' file; do
          printf '%s  %s\n' "$(sha256sum "$file" | cut -d' ' -f1)" "${file#./}"
        done \
      | sha256sum \
      | awk '{print "sha256:" $1}'
  )
}

api_get() {
  local url=$1
  if [ -n "${GH_TOKEN:-}" ]; then
    curl -fsSL \
      -H 'Accept: application/vnd.github+json' \
      -H "Authorization: Bearer $GH_TOKEN" \
      -H 'X-GitHub-Api-Version: 2022-11-28' \
      "$url"
  else
    curl -fsSL \
      -H 'Accept: application/vnd.github+json' \
      -H 'X-GitHub-Api-Version: 2022-11-28' \
      "$url"
  fi
}

before_digest=$(snapshot_repository)

api_get "https://api.github.com/repos/$repository" > "$work/repository-api.json"
if jq -e --arg repository "$repository" \
  '.full_name == $repository and .visibility == "public" and .private == false' \
  "$work/repository-api.json" >/dev/null; then
  public_state="CLOSED"
else
  public_state="REFUTED"
fi

core_repository=$(jq -r '.repository' "$base_lock")
release_tag=$(jq -r '.release.tag' "$base_lock")
api_get "https://api.github.com/repos/$core_repository/releases/tags/$release_tag" \
  > "$work/release-api.json"
api_get "https://api.github.com/repos/$core_repository/git/ref/tags/$release_tag" \
  > "$work/tag-ref.json"
tag_object_sha=$(jq -r '.object.sha' "$work/tag-ref.json")
api_get "https://api.github.com/repos/$core_repository/git/tags/$tag_object_sha" \
  > "$work/tag-object.json"

jq -S -n \
  --slurpfile release "$work/release-api.json" \
  --slurpfile ref "$work/tag-ref.json" \
  --slurpfile tag "$work/tag-object.json" \
  '{
    schema: "gooo/core-release-observation/v1",
    release: {
      tag: $release[0].tag_name,
      tag_object_type: $ref[0].object.type,
      tag_object_sha: $ref[0].object.sha,
      target_type: $tag[0].object.type,
      target_sha: $tag[0].object.sha,
      draft: $release[0].draft,
      prerelease: $release[0].prerelease,
      immutable: $release[0].immutable,
      assets: [
        $release[0].assets[]
        | {name, size, digest}
      ] | sort_by(.name)
    }
  }' > "$output/core-release.json"

release_identity_state() {
  local lock=$1
  local expected observed
  expected=$(jq -S -c '{
    tag: .release.tag,
    tag_object_type: .release.tag_object.type,
    tag_object_sha: .release.tag_object.sha,
    target_type: .release.target.type,
    target_sha: .release.target.sha,
    draft: .release.draft,
    prerelease: .release.prerelease,
    immutable: .release.immutable,
    assets: [.release.assets[] | {name, size, digest}] | sort_by(.name)
  }' "$lock")
  observed=$(jq -S -c '.release' "$output/core-release.json")
  if [ "$expected" = "$observed" ]; then
    printf 'CLOSED'
  else
    printf 'REFUTED'
  fi
}

if [ "$(release_identity_state "$base_lock")" != "CLOSED" ]; then
  echo 'base core release identity does not match its public observation' >&2
  exit 1
fi

archive=$(jq -r '.runtime.archive' "$base_lock")
checksums=$(jq -r '.runtime.checksums' "$base_lock")
archive_url=$(jq -r --arg name "$archive" \
  '.assets[] | select(.name == $name) | .browser_download_url' \
  "$work/release-api.json")
checksums_url=$(jq -r --arg name "$checksums" \
  '.assets[] | select(.name == $name) | .browser_download_url' \
  "$work/release-api.json")
curl -fsSL "$archive_url" -o "$work/$archive"
curl -fsSL "$checksums_url" -o "$work/$checksums"

archive_digest=$(digest_file "$work/$archive")
checksums_digest=$(digest_file "$work/$checksums")
expected_archive_digest=$(jq -r --arg name "$archive" \
  '.release.assets[] | select(.name == $name) | .digest' "$base_lock")
expected_checksums_digest=$(jq -r --arg name "$checksums" \
  '.release.assets[] | select(.name == $name) | .digest' "$base_lock")
test "$archive_digest" = "$expected_archive_digest"
test "$checksums_digest" = "$expected_checksums_digest"
checksum_entry=$(awk -v name="$archive" '$2 == name {print $1}' "$work/$checksums")
test -n "$checksum_entry"
test "sha256:$checksum_entry" = "$archive_digest"

mkdir -p "$work/runtime"
tar -xzf "$work/$archive" -C "$work/runtime"
gooo_binary=$(find "$work/runtime" -type f -name gooo -print -quit)
test -n "$gooo_binary"
chmod +x "$gooo_binary"
"$gooo_binary" version --json > "$work/version.json"
"$gooo_binary" check --json "$projection" > "$work/check.json"
"$gooo_binary" graph dump "$projection" > "$work/graph.json"

version_schema=$(jq -r '.schema_version' "$work/version.json")
check_schema=$(jq -r '.schema_version' "$work/check.json")
graph_schema=$(jq -r '.schema_version' "$work/graph.json")
version_status=$(jq -r '.status' "$work/version.json")
check_status=$(jq -r '.status' "$work/check.json")
expected_version_schema=$(jq -r '.runtime.version_schema' "$base_lock")
expected_check_schema=$(jq -r '.runtime.check_schema' "$base_lock")
expected_graph_schema=$(jq -r '.runtime.graph_schema' "$base_lock")
cli_state="CLOSED"
if [ "$version_schema" != "$expected_version_schema" ] \
  || [ "$check_schema" != "$expected_check_schema" ] \
  || [ "$graph_schema" != "$expected_graph_schema" ] \
  || [ "$(jq -r '.source_digest' "$work/graph.json")" != "$(digest_file "$projection")" ] \
  || [ "$check_status" != "ok" ] \
  || ! jq -e '.ir.status == "available" and (.ir.semantic_digest | length) > 0 and (.graph_hash | length) > 0' "$work/graph.json" >/dev/null; then
  cli_state="REFUTED"
fi

jq -S -n \
  --arg schema "gooo/released-design-cli-observation/v1" \
  --arg subject_sha "$subject_sha" \
  --arg binary_digest "$archive_digest" \
  --argjson checksum_verified true \
  --slurpfile version "$work/version.json" \
  --slurpfile check "$work/check.json" \
  --slurpfile graph "$work/graph.json" \
  '{
    schema: $schema,
    subject_sha: $subject_sha,
    binary: {
      digest: $binary_digest,
      checksum_verified: $checksum_verified
    },
    version: $version[0],
    check: $check[0],
    graph: $graph[0]
  }' > "$output/runtime.json"

expected_activities=$(jq -S -c '[.cells[].activity] | sort' "$denominator")
observed_activities=$(jq -S -c '[.nodes[] | select(.kind == "activity") | .name] | sort' "$work/graph.json")
meta_bound=$(jq -n --argjson expected "$expected_activities" --argjson observed "$observed_activities" \
  '$expected - ($expected - $observed) | length')
semantic_binding_state="CLOSED"
if [ "$expected_activities" != "$observed_activities" ]; then
  semantic_binding_state="REFUTED"
fi

if [ "$(jq -r '.target_cells' "$denominator")" -ne 12 ] \
  || [ "$(jq '.cells | length' "$denominator")" -ne 12 ] \
  || [ "$meta_bound" -ne 12 ]; then
  echo 'denominator or Gooo activity binding is not exactly 12/12' >&2
  exit 1
fi

after_observation_digest=$(snapshot_repository)
if [ "$before_digest" = "$after_observation_digest" ]; then
  zero_write_state="CLOSED"
  repository_writes=0
else
  zero_write_state="REFUTED"
  repository_writes=1
fi

cell() {
  local ordinal=$1 id=$2 proof=$3 activity=$4 state=$5 reason=$6 next_operation=$7
  jq -n -c \
    --argjson ordinal "$ordinal" \
    --arg id "$id" \
    --arg proof "$proof" \
    --arg activity "$activity" \
    --arg state "$state" \
    --arg reason "$reason" \
    --arg next_operation "$next_operation" \
    '{ordinal:$ordinal,id:$id,proof:$proof,activity:$activity,state:$state,reason:$reason,next_operation:$next_operation}'
}

build_report() {
  local phase=$1 candidate_fixture=$2 candidate_lock=$3 predecessor=$4 destination=$5
  local cells_file="$work/cells-$RANDOM.ndjson"
  : > "$cells_file"

  local release_state source_state token_state mapping_state lineage_state difference_state graph_state receipt_state trace_state replay_state
  local release_reason release_next token_reason token_next mapping_reason mapping_next graph_reason graph_next
  local token_count mapping_count lineage_token_count edge_count difference_count

  release_state=$(release_identity_state "$candidate_lock")
  release_reason="GOOO_RELEASE_IDENTITY_OBSERVED"
  release_next="NONE"
  if [ "$release_state" = "REFUTED" ]; then
    release_reason="GOOO_RELEASE_ASSET_DIGEST_MISMATCH"
    release_next="RESTORE_CORE_RELEASE_LOCK"
  fi

  source_state="CLOSED"
  if ! jq -e '
      ."$schema" == "https://www.designtokens.org/schemas/2025.10/format.json"
      and ([.. | objects | select(has("$value"))] | length) == 3
    ' "$candidate_fixture/tokens.json" >/dev/null \
    || ! jq -e '
      .schema == "gooo/parsed-code-connect-observation/v1"
      and .component.name == "Button"
      and .component.source.symbol == "Button"
    ' "$candidate_fixture/code-connect.json" >/dev/null \
    || [ ! -f "$candidate_fixture/button.tsx" ] \
    || [ ! -f "$candidate_fixture/generated/tokens.css" ] \
    || [ ! -f "$candidate_fixture/generated/tokens.ios.json" ] \
    || [ "$semantic_binding_state" != "CLOSED" ] \
    || [ "$meta_bound" -ne 12 ]; then
    source_state="REFUTED"
  fi

  token_count=$(jq '[.. | objects | select(has("$value"))] | length' "$candidate_fixture/tokens.json")
  token_state="CLOSED"
  token_reason="TOKEN_CLAIMS_EVIDENCED"
  token_next="NONE"
  if [ "$(jq -r '.color.action."$value"' "$candidate_fixture/tokens.json")" != "{color.blue}" ] \
    || ! jq -e '.color.blue."$value" != null and .color.blue."$type" == "color"' \
      "$candidate_fixture/tokens.json" >/dev/null \
    || ! jq -e '.radius.button."$value".value == 8 and .radius.button."$value".unit == "px"' \
      "$candidate_fixture/tokens.json" >/dev/null; then
    token_state="REFUTED"
    token_reason="TOKEN_ALIAS_TARGET_MISSING"
    token_next="RESTORE_EXPLICIT_TOKEN_ALIAS"
  fi

  mapping_count=$(jq '[.component.properties[] | select(
      (.figma_property == "Variant" and .figma_value == "Primary" and .code_property == "variant" and .code_value == "primary" and .code_type == "enum")
      or (.figma_property == "Disabled" and .figma_value == true and .code_property == "disabled" and .code_value == true and .code_type == "boolean")
    )] | length' "$candidate_fixture/code-connect.json")
  mapping_state="CLOSED"
  mapping_reason="FIGMA_CODE_PROPERTIES_BOUND"
  mapping_next="NONE"
  if [ "$mapping_count" -ne 2 ]; then
    mapping_state="UNKNOWN"
    mapping_reason="FIGMA_PROPERTY_MAPPING_MISSING"
    mapping_next="ADD_EXPLICIT_PROPERTY_MAPPING"
  fi

  lineage_token_count=$(jq '[.edges[] | select(.from.kind == "DTCG_TOKEN") | .from.locator] | unique | length' \
    "$candidate_fixture/lineage.json")
  lineage_state="CLOSED"
  if [ "$lineage_token_count" -ne 3 ] \
    || ! grep -Fq 'var(--color-action)' "$candidate_fixture/button.tsx" \
    || ! grep -Fq 'var(--radius-button)' "$candidate_fixture/button.tsx" \
    || ! grep -Fq -- '--color-blue:' "$candidate_fixture/generated/tokens.css" \
    || ! grep -Fq -- '--color-action:' "$candidate_fixture/generated/tokens.css" \
    || ! grep -Fq -- '--radius-button:' "$candidate_fixture/generated/tokens.css" \
    || ! jq -e '.radiusButton.value == 6 and .radiusButton.unit == "pt"' \
      "$candidate_fixture/generated/tokens.ios.json" >/dev/null; then
    lineage_state="UNKNOWN"
  fi

  difference_count=$(jq '[.differences[] | select(
      .source.locator == "/radius/button"
      and .source.value == 8
      and .observed.locator == "radiusButton"
      and .observed.value == 6
      and (.reason | length) > 0
      and (.scope | length) > 0
      and (.owner | length) > 0
      and (.reviewer | length) > 0
      and .expires_on >= "2027-12-31"
    )] | length' "$candidate_fixture/intentional-differences.json")
  difference_state="CLOSED"
  if [ "$difference_count" -ne 1 ]; then
    difference_state="UNKNOWN"
  fi

  edge_count=$(jq '.edges | length' "$candidate_fixture/lineage.json")
  graph_state="CLOSED"
  graph_reason="EVIDENCE_GRAPH_COHERENT"
  graph_next="NONE"
  if [ "$edge_count" -ne 9 ] \
    || [ "$(jq '[.edges[].id] | unique | length' "$candidate_fixture/lineage.json")" -ne 9 ] \
    || ! jq -e 'all(.edges[]; .from.kind != null and .from.locator != null and .to.kind != null and .to.locator != null and .from != .to)' \
      "$candidate_fixture/lineage.json" >/dev/null; then
    graph_state="REFUTED"
    graph_reason="EVIDENCE_GRAPH_CONTRADICTION"
    graph_next="REPAIR_EXPLICIT_LINEAGE"
  elif [ "$mapping_state" != "CLOSED" ]; then
    graph_state="UNKNOWN"
    graph_reason="DEPENDENCY_BLOCKED_BY_FIGMA_CODE_MAP"
    graph_next="RESOLVE_FIGMA_CODE_MAP"
  elif [ "$token_state" != "CLOSED" ]; then
    graph_state="UNKNOWN"
    graph_reason="DEPENDENCY_BLOCKED_BY_TOKEN_CLAIM"
    graph_next="RESOLVE_TOKEN_CLAIM"
  fi

  receipt_state="$cli_state"
  local receipt_reason="RELEASED_CHECK_RECEIPTS_OBSERVED"
  local receipt_next="NONE"
  if [ "$release_state" != "CLOSED" ]; then
    receipt_state="UNKNOWN"
    receipt_reason="DEPENDENCY_BLOCKED_BY_RELEASE_IDENTITY"
    receipt_next="RESOLVE_GOOO_RELEASE_IDENTITY"
  elif [ "$receipt_state" != "CLOSED" ]; then
    receipt_reason="RELEASED_CHECK_RECEIPT_MISMATCH"
    receipt_next="RESTORE_RELEASED_CHECK_SCHEMA"
  fi

  replay_state="CLOSED"
  trace_state="CLOSED"
  if [ "$phase" = "initial" ]; then
    replay_state="UNKNOWN"
    trace_state="UNKNOWN"
  elif [ ! -f "$predecessor" ] \
    || ! jq -e '
      .claim.state == "UNKNOWN"
      and .claim.stage == "REGRESSION"
      and .claim.step == "REPLAY_STABLE"
      and .claim.reason == "REPLAY_NOT_OBSERVED"
    ' "$predecessor" >/dev/null; then
    trace_state="UNKNOWN"
  fi

  cell 1 SUBJECT_PUBLIC FOUNDATION ObservePublicSubject \
    "$public_state" \
    "$([ "$public_state" = CLOSED ] && echo PUBLIC_SUBJECT_OBSERVED || echo PUBLIC_SUBJECT_NOT_PUBLIC)" \
    "$([ "$public_state" = CLOSED ] && echo NONE || echo PUBLISH_SUBJECT_REPOSITORY)" >> "$cells_file"
  cell 2 GOOO_RELEASE_IDENTITY FOUNDATION LockGoooReleaseIdentity \
    "$release_state" "$release_reason" "$release_next" >> "$cells_file"
  cell 3 DESIGN_SOURCE_BUNDLE FOUNDATION ObserveDesignSourceBundle \
    "$source_state" \
    "$([ "$source_state" = CLOSED ] && echo DESIGN_SOURCE_BUNDLE_OBSERVED || echo DESIGN_SOURCE_BUNDLE_INVALID)" \
    "$([ "$source_state" = CLOSED ] && echo NONE || echo RESTORE_DESIGN_SOURCE_BUNDLE)" >> "$cells_file"
  cell 4 RELEASED_CHECK_RECEIPT FOUNDATION ObserveReleasedCheckReceipt \
    "$receipt_state" "$receipt_reason" "$receipt_next" >> "$cells_file"
  cell 5 TOKEN_CLAIM_EVIDENCED COHERENCE BindTokenClaims \
    "$token_state" "$token_reason" "$token_next" >> "$cells_file"
  cell 6 FIGMA_CODE_MAP COHERENCE BindFigmaCodeProperties \
    "$mapping_state" "$mapping_reason" "$mapping_next" >> "$cells_file"
  cell 7 CODE_TOKEN_LINEAGE COHERENCE BindCodeTokenLineage \
    "$lineage_state" \
    "$([ "$lineage_state" = CLOSED ] && echo CODE_TOKEN_LINEAGE_BOUND || echo CODE_TOKEN_LINEAGE_MISSING)" \
    "$([ "$lineage_state" = CLOSED ] && echo NONE || echo ADD_EXPLICIT_TOKEN_LINEAGE)" >> "$cells_file"
  cell 8 INTENTIONAL_DIFFERENCE COHERENCE ReviewIntentionalDifference \
    "$difference_state" \
    "$([ "$difference_state" = CLOSED ] && echo INTENTIONAL_DIFFERENCE_REVIEWED || echo INTENTIONAL_DIFFERENCE_UNREVIEWED)" \
    "$([ "$difference_state" = CLOSED ] && echo NONE || echo REVIEW_PLATFORM_DIFFERENCE)" >> "$cells_file"
  cell 9 GRAPH_COHERENCE COHERENCE EvaluateEvidenceGraph \
    "$graph_state" "$graph_reason" "$graph_next" >> "$cells_file"
  cell 10 ZERO_WRITE REGRESSION ObserveZeroRepositoryWrite \
    "$zero_write_state" \
    "$([ "$zero_write_state" = CLOSED ] && echo REPOSITORY_ZERO_WRITE_OBSERVED || echo REPOSITORY_WRITE_OBSERVED)" \
    "$([ "$zero_write_state" = CLOSED ] && echo NONE || echo REMOVE_REPOSITORY_SIDE_EFFECT)" >> "$cells_file"
  cell 11 REPLAY_STABLE REGRESSION ObserveDeterministicReplay \
    "$replay_state" \
    "$([ "$replay_state" = CLOSED ] && echo DETERMINISTIC_REPLAY_OBSERVED || echo REPLAY_NOT_OBSERVED)" \
    "$([ "$replay_state" = CLOSED ] && echo NONE || echo RUN_DETERMINISTIC_REPLAY)" >> "$cells_file"
  cell 12 ADVERSARIAL_UNKNOWN_TRACE REGRESSION PreserveAdversarialUnknownTrace \
    "$trace_state" \
    "$([ "$trace_state" = CLOSED ] && echo ADVERSARIAL_UNKNOWN_TRACE_PRESERVED || echo UNKNOWN_TRACE_NOT_PRESERVED)" \
    "$([ "$trace_state" = CLOSED ] && echo NONE || echo CONSUME_PREDECESSOR_CLAIM_TRACE)" >> "$cells_file"

  local closed unknown refuted total decision resolution claim_status claim_state problem stage step reason next_operation
  total=$(wc -l < "$cells_file" | tr -d ' ')
  closed=$(jq -s '[.[] | select(.state == "CLOSED")] | length' "$cells_file")
  unknown=$(jq -s '[.[] | select(.state == "UNKNOWN")] | length' "$cells_file")
  refuted=$(jq -s '[.[] | select(.state == "REFUTED")] | length' "$cells_file")

  if [ "$refuted" -gt 0 ]; then
    decision="FAIL_CLOSED"
    resolution="CONTRADICTION_CLASS"
    claim_status="CONTESTED"
    claim_state="REFUTED"
    problem=$(jq -s -c '[.[] | select(.state == "REFUTED")][0]' "$cells_file")
  elif [ "$unknown" -gt 0 ]; then
    if [ "$phase" = "initial" ]; then
      decision="PROGRESS_OBSERVED"
    else
      decision="DESIGN_EVIDENCE_NEEDS_INPUT"
    fi
    resolution="PREREQUISITE_CLASS"
    claim_status="ACTIVE"
    claim_state="UNKNOWN"
    problem=$(jq -s -c '[.[] | select(.state == "UNKNOWN")][0]' "$cells_file")
  else
    decision="DESIGN_EVIDENCE_READY"
    resolution="EXACT"
    claim_status="DISCHARGED"
    claim_state="CLOSED"
    problem='{"proof":null,"id":null,"reason":"DESIGN_EVIDENCE_PREREQUISITES_CLOSED","next_operation":"NONE"}'
  fi
  stage=$(jq -r '.proof // empty' <<<"$problem")
  step=$(jq -r '.id // empty' <<<"$problem")
  reason=$(jq -r '.reason' <<<"$problem")
  next_operation=$(jq -r '.next_operation' <<<"$problem")

  local predecessor_json='null'
  if [ -f "$predecessor" ]; then
    predecessor_json=$(jq -n \
      --arg report_digest "$(jq -r '.report_digest' "$predecessor")" \
      --arg artifact_digest "$(digest_file "$predecessor")" \
      --argjson claim "$(jq -c '.claim' "$predecessor")" \
      '{report_digest:$report_digest,artifact_digest:$artifact_digest,claim:$claim}')
  fi

  local proofs indicators cells_json body body_digest
  cells_json=$(jq -s . "$cells_file")
  proofs=$(jq -n \
    --slurpfile denominator "$denominator" \
    --slurpfile cells "$cells_file" '
      [$denominator[0].proof_totals[] as $proof | {
        choice: $proof.choice,
        closed: ([$cells[] | select(.proof == $proof.choice and .state == "CLOSED")] | length),
        total: $proof.total
      }]
    ')
  indicators=$(jq -n \
    --argjson closed "$closed" \
    --argjson unknown "$unknown" \
    --argjson refuted "$refuted" \
    --argjson meta_bound "$meta_bound" \
    --argjson mapping_count "$mapping_count" \
    --argjson token_lineage "$lineage_token_count" \
    --argjson difference_count "$difference_count" \
    --argjson edge_count "$edge_count" \
    --argjson repository_writes "$repository_writes" \
    --argjson cli_receipts "$([ "$receipt_state" = CLOSED ] && echo 3 || echo 0)" '
      [
        {id:"gooo.metric.design-evidence.readiness.v2",value:$closed,total:12,state:(if $closed == 12 then "SATISFIED" else "GAP" end)},
        {id:"gooo.metric.design-evidence.meta-binding.v2",value:$meta_bound,total:12,state:(if $meta_bound == 12 then "SATISFIED" else "GAP" end)},
        {id:"gooo.metric.design-evidence.claim-edges.v1",value:$edge_count,total:9,state:(if $edge_count == 9 then "SATISFIED" else "GAP" end)},
        {id:"gooo.metric.design-evidence.property-mappings.v1",value:$mapping_count,total:2,state:(if $mapping_count == 2 then "SATISFIED" else "GAP" end)},
        {id:"gooo.metric.design-evidence.token-lineage.v1",value:$token_lineage,total:3,state:(if $token_lineage == 3 then "SATISFIED" else "GAP" end)},
        {id:"gooo.metric.design-evidence.intentional-differences.v1",value:$difference_count,total:1,state:(if $difference_count == 1 then "SATISFIED" else "GAP" end)},
        {id:"gooo.metric.design-evidence.released-cli-receipts.v2",value:$cli_receipts,total:3,state:(if $cli_receipts == 3 then "SATISFIED" else "GAP" end)},
        {id:"gooo.metric.design-evidence.unknown-prerequisites.v1",value:$unknown,total:12,state:(if $unknown == 0 then "SATISFIED" else "GAP" end)},
        {id:"gooo.metric.design-evidence.refuted-prerequisites.v1",value:$refuted,total:12,state:(if $refuted == 0 then "SATISFIED" else "GAP" end)},
        {id:"gooo.metric.design-evidence.repository-writes.v1",value:$repository_writes,total:1,state:(if $repository_writes == 0 then "SATISFIED" else "GAP" end)}
      ]
    ')

  body="$work/body-$RANDOM.json"
  jq -S -n \
    --arg schema "gooo/design-evidence-readiness-report/v2" \
    --arg subject_repository "$repository" \
    --arg subject_sha "$subject_sha" \
    --arg denominator_digest "$(canonical_digest "$denominator")" \
    --arg phase "$phase" \
    --arg decision "$decision" \
    --arg resolution "$resolution" \
    --arg claim_status "$claim_status" \
    --arg claim_state "$claim_state" \
    --arg stage "$stage" \
    --arg step "$step" \
    --arg reason "$reason" \
    --arg next_operation "$next_operation" \
    --argjson closed "$closed" \
    --argjson unknown "$unknown" \
    --argjson refuted "$refuted" \
    --argjson total "$total" \
    --argjson repository_writes "$repository_writes" \
    --arg before_digest "$before_digest" \
    --arg after_digest "$after_observation_digest" \
    --arg release_lock_digest "$(canonical_digest "$candidate_lock")" \
    --arg token_digest "$(canonical_digest "$candidate_fixture/tokens.json")" \
    --arg code_connect_digest "$(canonical_digest "$candidate_fixture/code-connect.json")" \
    --arg code_digest "$(digest_file "$candidate_fixture/button.tsx")" \
    --arg lineage_digest "$(canonical_digest "$candidate_fixture/lineage.json")" \
    --arg difference_digest "$(canonical_digest "$candidate_fixture/intentional-differences.json")" \
    --arg projection_digest "$(digest_file "$projection")" \
    --arg core_tag "$release_tag" \
    --arg core_tag_object "$tag_object_sha" \
    --arg core_target "$(jq -r '.object.sha' "$work/tag-object.json")" \
    --arg binary_digest "$archive_digest" \
    --arg version_schema "$version_schema" \
    --arg version_status "$version_status" \
    --arg check_schema "$check_schema" \
    --arg check_status "$check_status" \
    --arg graph_schema "$graph_schema" \
    --arg graph_hash "$(jq -r '.graph_hash' "$work/graph.json")" \
    --arg graph_source_digest "$(jq -r '.source_digest' "$work/graph.json")" \
    --arg semantic_ir_digest "$(jq -r '.ir.semantic_digest' "$work/graph.json")" \
    --arg semantic_binding_state "$semantic_binding_state" \
    --argjson cells "$cells_json" \
    --argjson indicators "$indicators" \
    --argjson proofs "$proofs" \
    --argjson predecessor "$predecessor_json" '
      {
        schema:$schema,
        subject:{repository:$subject_repository,sha:$subject_sha},
        denominator:{cells:12,digest:$denominator_digest},
        phase:$phase,
        decision:$decision,
        resolution:$resolution,
        claim:{
          id:"design://claim/button-system-evidence-ready",
          status:$claim_status,
          state:$claim_state,
          resolution:$resolution,
          stage:(if $stage == "" then null else $stage end),
          step:(if $step == "" then null else $step end),
          reason:$reason,
          next_operation:$next_operation
        },
        predecessor:$predecessor,
        cells:$cells,
        summary:{closed:$closed,unknown:$unknown,refuted:$refuted,total:$total,repository_writes:$repository_writes},
        indicators:$indicators,
        proofs:$proofs,
        evidence:{
          authority:{
            projection_digest:$projection_digest,
            binding_type:"RELEASED_GOOO_GRAPH_ACTIVITY_SET",
            compiler_semantic_binding:(if $semantic_binding_state == "CLOSED" then "OBSERVED" else "REFUTED" end),
            compiler_source_span_binding:"NOT_AVAILABLE",
            cross_format_semantic_binding:"NOT_CLAIMED",
            binding_resolution:"ACTIVITY_IDENTITY_AND_SOURCE_DIGEST",
            graph_schema:$graph_schema,
            graph_hash:$graph_hash,
            graph_source_digest:$graph_source_digest,
            semantic_ir_digest:$semantic_ir_digest
          },
          design:{tokens_digest:$token_digest,code_connect_digest:$code_connect_digest,code_digest:$code_digest,lineage_digest:$lineage_digest,intentional_difference_digest:$difference_digest},
          core_release:{tag:$core_tag,tag_object_sha:$core_tag_object,target_sha:$core_target,lock_digest:$release_lock_digest,binary_digest:$binary_digest},
          released_cli:{version_schema:$version_schema,version_status:$version_status,check_schema:$check_schema,check_status:$check_status,graph_schema:$graph_schema},
          repository:{before_digest:$before_digest,after_digest:$after_digest,writes:$repository_writes}
        }
      }
    ' > "$body"
  body_digest=$(digest_file "$body")
  jq -S --arg report_digest "$body_digest" '. + {report_digest:$report_digest}' "$body" > "$destination"
}

build_report initial "$fixture" "$base_lock" "$work/no-predecessor" "$output/initial.json"
jq -e '
  .decision == "PROGRESS_OBSERVED"
  and .resolution == "PREREQUISITE_CLASS"
  and .summary.closed == 10
  and .summary.unknown == 2
  and .summary.refuted == 0
  and .summary.total == 12
  and .claim.stage == "REGRESSION"
  and .claim.step == "REPLAY_STABLE"
  and .claim.reason == "REPLAY_NOT_OBSERVED"
' "$output/initial.json" >/dev/null

build_report final "$fixture" "$base_lock" "$output/initial.json" "$output/report.json"
build_report final "$fixture" "$base_lock" "$output/initial.json" "$output/replay.json"
cmp -s "$output/report.json" "$output/replay.json"
jq -e '
  .decision == "DESIGN_EVIDENCE_READY"
  and .resolution == "EXACT"
  and .summary.closed == 12
  and .summary.unknown == 0
  and .summary.refuted == 0
  and .summary.total == 12
  and .summary.repository_writes == 0
  and ([.proofs[] | select(.choice == "FOUNDATION" and .closed == 4 and .total == 4)] | length) == 1
  and ([.proofs[] | select(.choice == "COHERENCE" and .closed == 5 and .total == 5)] | length) == 1
  and ([.proofs[] | select(.choice == "REGRESSION" and .closed == 3 and .total == 3)] | length) == 1
' "$output/report.json" >/dev/null

cp -R "$fixture" "$work/mapping-gap"
jq '.component.properties |= map(select(.figma_property != "Disabled"))' \
  "$work/mapping-gap/code-connect.json" > "$work/mapping-gap/code-connect.next.json"
mv "$work/mapping-gap/code-connect.next.json" "$work/mapping-gap/code-connect.json"
build_report final "$work/mapping-gap" "$base_lock" "$output/initial.json" "$output/mapping-unknown.json"
jq -e '
  .decision == "DESIGN_EVIDENCE_NEEDS_INPUT"
  and .claim.state == "UNKNOWN"
  and .claim.stage == "COHERENCE"
  and .claim.step == "FIGMA_CODE_MAP"
  and .claim.reason == "FIGMA_PROPERTY_MAPPING_MISSING"
  and .claim.next_operation == "ADD_EXPLICIT_PROPERTY_MAPPING"
  and .summary.unknown == 2
  and .summary.refuted == 0
' "$output/mapping-unknown.json" >/dev/null

cp -R "$fixture" "$work/alias-broken"
jq '.color.action."$value" = "{color.missing}"' \
  "$work/alias-broken/tokens.json" > "$work/alias-broken/tokens.next.json"
mv "$work/alias-broken/tokens.next.json" "$work/alias-broken/tokens.json"
build_report final "$work/alias-broken" "$base_lock" "$output/initial.json" "$output/alias-refuted.json"
jq -e '
  .decision == "FAIL_CLOSED"
  and .claim.state == "REFUTED"
  and .claim.stage == "COHERENCE"
  and .claim.step == "TOKEN_CLAIM_EVIDENCED"
  and .claim.reason == "TOKEN_ALIAS_TARGET_MISSING"
  and .summary.refuted == 1
' "$output/alias-refuted.json" >/dev/null

jq '(.release.assets[] | select(.name == "gooo-linux-amd64.tar.gz") | .digest) = "sha256:0000000000000000000000000000000000000000000000000000000000000000"' \
  "$base_lock" > "$work/tampered-release-lock.json"
build_report final "$fixture" "$work/tampered-release-lock.json" "$output/initial.json" "$output/release-refuted.json"
jq -e '
  .decision == "FAIL_CLOSED"
  and .claim.state == "REFUTED"
  and .claim.stage == "FOUNDATION"
  and .claim.step == "GOOO_RELEASE_IDENTITY"
  and .claim.reason == "GOOO_RELEASE_ASSET_DIGEST_MISMATCH"
  and .summary.refuted == 1
' "$output/release-refuted.json" >/dev/null

sed 's/^namespace designevidence$/namespace design_evidence/' \
  "$projection" > "$work/invalid-namespace.gooo"
"$gooo_binary" check --json "$work/invalid-namespace.gooo" > "$work/invalid-namespace-check.json"
set +e
"$gooo_binary" graph dump "$work/invalid-namespace.gooo" \
  > "$work/invalid-namespace-graph.json" \
  2> "$work/invalid-namespace-graph.stderr"
invalid_graph_exit=$?
set -e
test "$invalid_graph_exit" -ne 0
jq -e '.schema_version == "gooo/diagnostics/v1" and .status == "ok"' \
  "$work/invalid-namespace-check.json" >/dev/null
grep -Fq 'semantic.invalid' "$work/invalid-namespace-graph.stderr"
jq -S -n \
  --slurpfile check "$work/invalid-namespace-check.json" \
  --argjson graph_exit "$invalid_graph_exit" \
  '{
    schema:"gooo/compiler-semantic-depth-counterexample/v1",
    claim:{
      id:"design://claim/compiler-command-semantic-depth",
      status:"CONTESTED",
      state:"REFUTED",
      resolution:"CONTRADICTION_CLASS",
      stage:"FOUNDATION",
      step:"RELEASED_SEMANTIC_RECEIPTS",
      reason:"SEMANTIC_LOWERING_REJECTED_AFTER_CHECK_OK",
      next_operation:"USE_URI_SAFE_NAMESPACE"
    },
    observation:{
      check_schema:$check[0].schema_version,
      check_status:$check[0].status,
      graph_exit:$graph_exit,
      graph_diagnostic:"semantic.invalid"
    }
  }' > "$output/semantic-depth-refuted.json"

final_digest=$(snapshot_repository)
final_writes=0
if [ "$before_digest" != "$final_digest" ]; then
  final_writes=1
fi
jq -S -n \
  --arg schema "gooo/read-only-repository-observation/v1" \
  --arg before_digest "$before_digest" \
  --arg after_digest "$final_digest" \
  --argjson writes "$final_writes" \
  '{schema:$schema,before_digest:$before_digest,after_digest:$after_digest,writes:$writes}' \
  > "$output/repository.json"
test "$final_writes" -eq 0

jq -S -n \
  --slurpfile initial "$output/initial.json" \
  --slurpfile report "$output/report.json" \
  --slurpfile mapping "$output/mapping-unknown.json" \
  --slurpfile alias "$output/alias-refuted.json" \
  --slurpfile release "$output/release-refuted.json" \
  --slurpfile semantic_depth "$output/semantic-depth-refuted.json" \
  '{
    schema:"gooo/design-evidence-ci-receipt/v2",
    transition:{
      initial:{closed:$initial[0].summary.closed,unknown:$initial[0].summary.unknown,refuted:$initial[0].summary.refuted,total:$initial[0].summary.total,report_digest:$initial[0].report_digest},
      final:{closed:$report[0].summary.closed,unknown:$report[0].summary.unknown,refuted:$report[0].summary.refuted,total:$report[0].summary.total,report_digest:$report[0].report_digest}
    },
    counterexamples:{
      mapping:{state:$mapping[0].claim.state,stage:$mapping[0].claim.stage,step:$mapping[0].claim.step,reason:$mapping[0].claim.reason},
      alias:{state:$alias[0].claim.state,stage:$alias[0].claim.stage,step:$alias[0].claim.step,reason:$alias[0].claim.reason},
      release:{state:$release[0].claim.state,stage:$release[0].claim.stage,step:$release[0].claim.step,reason:$release[0].claim.reason},
      semantic_depth:{state:$semantic_depth[0].claim.state,stage:$semantic_depth[0].claim.stage,step:$semantic_depth[0].claim.step,reason:$semantic_depth[0].claim.reason}
    },
    deterministic_replay:true,
    repository_writes:0,
    local_test_executions:0
  }' > "$output/receipt.json"

rm -rf "$work"
