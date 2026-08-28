#!/usr/bin/env bash
set -euo pipefail
trap 'echo "released-domain-envelope-v2 exporter failed at line $LINENO" >&2' ERR

if test "$#" -ne 8; then
  echo "usage: export-released-domain-envelope-v2.sh ROOT LOCK DENOMINATOR FIXTURE CORE_RECEIPTS SOURCE REPLAY OUTPUT" >&2
  exit 64
fi

repository=$(realpath "$1")
lock=$2
denominator=$3
fixture=$4
core_receipts=$5
source_file=$6
replay_file=$7
output=$(realpath -m "$8")

case "$output" in
  "$repository"|"$repository"/*)
    echo "output must be outside repository" >&2
    exit 65
    ;;
esac

for file in "$lock" "$denominator" "$fixture" "$core_receipts" "$source_file" "$replay_file"; do
  test -f "$file" || { echo "missing input: $file" >&2; exit 66; }
done

test "$(jq -r .schema "$lock")" = "gooo/design-evidence/released-domain-envelope-adoption-release-lock/v2"
test "$(jq -r .schema "$denominator")" = "gooo/design-evidence/released-domain-envelope-adoption-denominator/v2"
test "$(jq -r .schema "$fixture")" = "gooo/design-evidence/released-domain-envelope-adoption/v2"

jq -n -e --slurpfile denominator "$denominator" --slurpfile receipts "$core_receipts" '
  ($denominator[0]) as $d |
  ($receipts[0]) as $r |
  (($d.target_cells == 12) and ($r|length == $d.target_cells) and
   (([$r[]|.selector.name]|sort) == ([$d.cells[].activity]|sort)) and
   (all($r[];
     .schema == "gooo/activity-cardinality-resolution/v1" and
     .decision == "CLOSED" and .occurrences == 1 and
     .claim.state == "CLOSED" and .claim.reason == "ACTIVITY_UNIQUELY_RESOLVED")))
' >/dev/null

source_schema=$(jq -r .source.schema "$fixture")
relation_array=$(jq -r .source.relation_array "$fixture")
expected_relations=$(jq -r .source.expected_relations "$fixture")
expected_claim_tuples=$(jq -r .source.expected_claim_tuples "$fixture")
test "$(jq -r .schema "$source_file")" = "$source_schema"
test "$(jq --arg key "$relation_array" '.[$key]|length' "$source_file")" -eq "$expected_relations"
test "$(jq '.claim_tuples|length' "$source_file")" -eq "$expected_claim_tuples"
jq -e --argjson expected "$expected_claim_tuples" '
  ([.claim_tuples[]|select(.fields_observed==6)|select(
    (.claim|has("stage")) and (.claim|has("step")) and
    (.claim|has("reason")) and (.claim|has("unknown_class")) and
    (.claim|has("next_operation")))]|length)==$expected and
  all(.claim_tuples[];
    (.claim.state|IN("CLOSED","UNKNOWN","REFUTED")))
' "$source_file" >/dev/null

replay_schema=$(jq -r .source.replay_schema "$fixture")
test "$(jq -r .schema "$replay_file")" = "$replay_schema"
replay_satisfied_path=$(jq -c .source.replay_satisfied_path "$fixture")
replay_total_path=$(jq -c .source.replay_total_path "$fixture")
source_satisfied=$(jq -r --argjson path "$replay_satisfied_path" 'getpath($path)' "$replay_file")
source_total=$(jq -r --argjson path "$replay_total_path" 'getpath($path)' "$replay_file")
expected_replay=$(jq -r .source.expected_replay_comparisons "$fixture")
test "$source_satisfied" -eq "$source_total"
test "$source_total" -eq "$expected_replay"

source_member=$(jq -r .design_evidence.source_asset.member "$lock")
source_asset=$(jq -r .design_evidence.source_asset.name "$lock")
source_sha=$(jq -r .design_evidence.source_asset.sha256 "$lock")
source_repository=$(jq -r .design_evidence.repository "$lock")
source_tag=$(jq -r .design_evidence.tag "$lock")
source_target=$(jq -r .design_evidence.target_commit_sha "$lock")
project_id=$(jq -r .project.id "$fixture")
domain=$(jq -r .project.domain "$fixture")

mkdir -p "$output"
test -z "$(find "$output" -mindepth 1 -maxdepth 1 -print -quit)"
: > "$output/evidence.ndjson"
: > "$output/relations.ndjson"
: > "$output/resolutions.ndjson"
: > "$output/unknowns.ndjson"

ordinal=0
jq -cS --arg key "$relation_array" '.[$key][]' "$source_file" | while IFS= read -r row; do
  ordinal=$((ordinal+1))
  printf -v suffix '%03d' "$ordinal"
  relation_id=$(jq -r .id <<<"$row")
  test -n "$relation_id"
  evidence_id="gooo://interchange/evidence/$project_id/$suffix"
  value_sha=$(printf '%s' "$row" | sha256sum | awk '{print $1}')
  pointer="/$relation_array/$((ordinal-1))"

  jq -cS -n --arg id "$evidence_id" --arg relation_id "$relation_id" \
    --arg repository "$source_repository" --arg tag "$source_tag" --arg target "$source_target" \
    --arg asset "$source_asset" --arg asset_sha "$source_sha" --arg member "$source_member" \
    --arg pointer "$pointer" --arg value_sha "$value_sha" \
    '{schema:"gooo/interchange/evidence/v2",id:$id,relation_id:$relation_id,
      source:{repository:$repository,tag:$tag,target_commit_sha:$target,asset_name:$asset,
        asset_sha256:$asset_sha,member:$member,json_pointer:$pointer},
      observation:{kind:"RELEASED_JSON_VALUE",value_sha256:$value_sha},
      authority:{claim_scope:"RELEASED_DECLARATION_ONLY",semantic_truth_claimed:false}}' \
    >> "$output/evidence.ndjson"

  jq -e '.state|IN("MATCH","MISMATCH","UNKNOWN")' <<<"$row" >/dev/null
  jq -cS -n --argjson row "$row" --arg evidence_id "$evidence_id" \
    '{schema:"gooo/interchange/relation/v2",id:$row.id,kind:"DESIGN_CODE_RELATION",
      domain_state:$row.state,disposition:$row.disposition,
      left:{kind:"DESIGN_SUBJECT",id:$row.from},right:{kind:"CODE_SUBJECT",id:$row.to},
      evidence_ids:[$evidence_id],
      attributes:{review_action:$row.review_action,evidence_count:$row.evidence_count},
      authority:{domain_semantics_preserved:true,claim_resolution_embedded:false}}' \
    >> "$output/relations.ndjson"

  if test "$(jq -r .state <<<"$row")" = UNKNOWN; then
    jq -e 'has("stage") and has("step") and has("reason") and has("unknown_class") and has("next_operation") and has("blocked_by") and (.blocked_by|type)=="array" and (.unknown_class|IN("DIRECT_MISSING","DEPENDENCY_BLOCKED"))' <<<"$row" >/dev/null
    jq -cS -n --argjson row "$row" \
      '{schema:"gooo/interchange/resolution/v2",relation_id:$row.id,state:"UNKNOWN",
        stage:$row.stage,step:$row.step,reason:$row.reason,unknown_class:$row.unknown_class,
        next_operation:$row.next_operation,blocked_by:$row.blocked_by,
        authority:{source:"RELEASED_PRODUCT_EVIDENCE",state_inference_authorized:false}}' \
      | tee -a "$output/resolutions.ndjson" >> "$output/unknowns.ndjson"
  elif test "$(jq -r .state <<<"$row")" = REFUTED; then
    jq -cS -n --argjson row "$row" \
      '{schema:"gooo/interchange/resolution/v2",relation_id:$row.id,state:"REFUTED",
        stage:$row.stage,step:$row.step,reason:$row.reason,unknown_class:null,
        next_operation:$row.next_operation,blocked_by:($row.blocked_by//[]),
        authority:{source:"RELEASED_PRODUCT_EVIDENCE",state_inference_authorized:false}}' \
      >> "$output/resolutions.ndjson"
  else
    jq -cS -n --argjson row "$row" \
      '{schema:"gooo/interchange/resolution/v2",relation_id:$row.id,state:"CLOSED",
        stage:null,step:null,reason:$row.reason,unknown_class:null,next_operation:"NONE",blocked_by:[],
        authority:{source:"RELEASED_PRODUCT_EVIDENCE",state_inference_authorized:false}}' \
      >> "$output/resolutions.ndjson"
  fi
done

relation_count=$(wc -l < "$output/relations.ndjson" | tr -d ' ')
evidence_count=$(wc -l < "$output/evidence.ndjson" | tr -d ' ')
resolution_count=$(wc -l < "$output/resolutions.ndjson" | tr -d ' ')
unknown_count=$(wc -l < "$output/unknowns.ndjson" | tr -d ' ')
test "$relation_count" -eq "$expected_relations"
test "$evidence_count" -eq "$relation_count"
test "$resolution_count" -eq "$relation_count"

claim_tuples=$(jq -cS '.claim_tuples | map(.claim |= (. + {blocked_by:(.blocked_by//[])}))' "$source_file")
jq -S -n --arg project_id "$project_id" --arg domain "$domain" \
  --arg repository "$source_repository" --arg tag "$source_tag" --arg target "$source_target" \
  --arg asset "$source_asset" --arg asset_sha "$source_sha" --arg member "$source_member" --arg source_schema "$source_schema" \
  --argjson relation_count "$relation_count" --argjson evidence_count "$evidence_count" \
  --argjson resolution_count "$resolution_count" --argjson unknown_count "$unknown_count" \
  --argjson claim_tuples_total "$expected_claim_tuples" \
  --argjson claim_tuples "$claim_tuples" --argjson meta_activities "$(jq '.target_cells' "$denominator")" \
  '{schema:"gooo/interchange/project/v2",project_id:$project_id,domain:$domain,
    release:{repository:$repository,tag:$tag,target_commit_sha:$target},
    source:{asset_name:$asset,asset_sha256:$asset_sha,member:$member,schema:$source_schema},
    relation_count:$relation_count,evidence_count:$evidence_count,resolution_count:$resolution_count,
    unknown_count:$unknown_count,
    projection:{owner:"DESIGN_EVIDENCE",generator:"PRODUCT_OWNED_GOOO_ACTIVITY_PROJECTION",
      meta_activity_receipts:$meta_activities,claim_tuples_observed:($claim_tuples|length),claim_tuples_total:$claim_tuples_total,
      resolution_precedence:["REFUTED","UNKNOWN","CLOSED"]},
    claim_tuples:$claim_tuples,
    authority:{projection_owner:"INTERCHANGE_SPECIFICATION",domain_release_adoption_claimed:false,
      source_repository_writes:0,product_generation_authorized:false}}' > "$output/project.json"

jq -S -n '{schema:"gooo/interchange/conformance/v2",required_files:8,
  required_local_checks:["EXACT_FILE_SET","PROJECT_IDENTITY_AND_AUTHORITY","CARDINALITIES","EVIDENCE_ANCHORS","RELATION_ANCHORS","RESOLUTION_TUPLES","UNKNOWN_SUBSET","SOURCE_REPLAY","SHA256_CHECKSUMS","DETERMINISTIC_REPLAY"],
  external_required_gates:0,repository_writes:0,product_generation_authorized:false}' > "$output/conformance.json"

payload_sha=$(cd "$output" && sha256sum project.json evidence.ndjson relations.ndjson resolutions.ndjson unknowns.ndjson conformance.json | sha256sum | awk '{print $1}')
jq -S -n --arg receipt_schema "$replay_schema" --argjson satisfied "$source_satisfied" --argjson total "$source_total" --arg payload_sha "$payload_sha" \
  '{schema:"gooo/interchange/replay/v2",source:{receipt_schema:$receipt_schema,comparisons_satisfied:$satisfied,comparisons_total:$total,receipt_verified:true},
    projection:{payload_files:6,payload_sha256:$payload_sha},
    authority:{determinism_is_semantic_truth:false,product_execution_authorized:false}}' > "$output/replay.json"
(cd "$output" && sha256sum project.json evidence.ndjson relations.ndjson resolutions.ndjson unknowns.ndjson conformance.json replay.json > checksums.txt)
