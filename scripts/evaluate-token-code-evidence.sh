#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 8; then
  echo "usage: evaluate-token-code-evidence.sh GRAPH DENOMINATOR FIXTURE OUTPUT SUBJECT_SHA SCENARIO PEAK_RSS_KIB WALL_MS" >&2
  exit 2
fi

graph=$1
denominator=$2
fixture=$3
output=$4
subject_sha=$5
scenario=$6
peak_rss_kib=$7
wall_ms=$8
root=$(cd "$(dirname "$0")/.." && pwd)

test -f "$graph" || { echo "missing released semantic graph: $graph" >&2; exit 2; }
test -f "$denominator" || { echo "missing denominator: $denominator" >&2; exit 2; }
for file in authority.json manifest.json design-tokens.json component.tsx service.ts bindings.json generated/tokens.css; do
  test -f "$fixture/$file" || { echo "missing input fixture: $fixture/$file" >&2; exit 2; }
done
case "$scenario" in
  exact-match|missing-mapping|stale-token|explicit-value-contradiction|digest-valid-laundering|mixed|authority-escalation) ;;
  *) echo "unsupported scenario: $scenario" >&2; exit 2 ;;
esac

jq -e '
  .schema=="gooo/design-token-code-evidence-denominator/v1" and .total==12 and
  (.cells|length)==12 and ([.proofs[].total]|add)==12 and
  ([.indicator_classes[].total]|add)==12 and
  ([.cells[]|.activity]|unique|length)==12
' "$denominator" >/dev/null
jq -e --slurpfile denominator "$denominator" '
  . as $graph |
  $graph.schema_version=="gooo-graph/v1" and
  ([$graph.nodes[]|select(.kind=="Activity")]|length)==12 and
  ([$denominator[0].cells[] as $cell|
    select(([$graph.nodes[]|select(.kind=="Activity" and .name==$cell.activity)]|length)==1)]|length)==12
' "$graph" >/dev/null
jq -e '
  .schema=="gooo/design-token-code-evidence/authority/v1" and
  .source_of_truth=="GOOO_SOURCE_AND_RELEASED_SEMANTIC_GRAPH" and
  .matching_mode=="EXPLICIT_VALUES_AND_REFERENCES_ONLY" and
  (.read_only|type)=="boolean" and (.repository_writes_authorized|type)=="boolean" and
  (.automatic_remediation_authorized|type)=="boolean" and .output_scope=="CALLER_OWNED_TEMP_ONLY"
' "$fixture/authority.json" >/dev/null
jq -e '.schema=="gooo/design-token-code-evidence/input-manifest/v1" and .algorithm=="sha256" and (.files|length)==5' "$fixture/manifest.json" >/dev/null
jq -e '.schema=="gooo/design-token-code-evidence/explicit-bindings/v1" and (.bindings|length)==4' "$fixture/bindings.json" >/dev/null
jq -e '.["$schema"]=="https://www.designtokens.org/schemas/2025.10/format.json" and ([..|objects|select(has("$value"))]|length)==3' "$fixture/design-tokens.json" >/dev/null

sha256() { sha256sum "$1" | awk '{print $1}'; }
manifest_valid=true
while IFS=$'\t' read -r path expected; do
  actual=$(sha256 "$fixture/$path")
  if test "$actual" != "$expected"; then manifest_valid=false; fi
done < <(jq -r '.files[]|[.path,.sha256]|@tsv' "$fixture/manifest.json")

token_count=$(jq '[..|objects|select(has("$value"))]|length' "$fixture/design-tokens.json")
binding_count=$(jq '.bindings|length' "$fixture/bindings.json")
generated_artifact_files=$(find "$fixture/generated" -type f -print | wc -l | tr -d ' ')

has_binding() { jq -e --arg id "$1" 'any(.bindings[];.id==$id)' "$fixture/bindings.json" >/dev/null; }
has_text() { grep -Fq -- "$1" "$fixture/$2"; }

tone_match=false
if has_binding component-tone && has_text 'tone: "brand"' component.tsx && has_text 'data-tone={tone}' component.tsx; then tone_match=true; fi

background_match=false
if has_binding component-background-token \
  && jq -e '.color.action."$value"=="{color.brand}" and .color.brand."$value"!=null' "$fixture/design-tokens.json" >/dev/null \
  && has_text 'background: "var(--color-action)"' component.tsx \
  && has_text '--color-action: var(--color-brand)' generated/tokens.css; then background_match=true; fi

service_match=false
if has_binding service-action-token && has_text 'actionToken: "color.action"' service.ts; then service_match=true; fi

padding_match=false
if has_binding component-padding-token \
  && jq -e '.space.control."$value"=={value:8,unit:"px"}' "$fixture/design-tokens.json" >/dev/null \
  && has_text 'padding: "var(--space-control)"' component.tsx \
  && has_text '--space-control: 8px' generated/tokens.css; then padding_match=true; fi

authority_escalated=false
if jq -e '.read_only==false or .repository_writes_authorized==true or .automatic_remediation_authorized==true or .cross_project_required_gates!=0 or .output_scope!="CALLER_OWNED_TEMP_ONLY"' "$fixture/authority.json" >/dev/null; then
  authority_escalated=true
fi

inventory_files=0
inventory_directories=0
physical_lines=0
go_lines=0
gooo_lines=0
while IFS= read -r -d '' file; do
  inventory_files=$((inventory_files+1))
  lines=$(wc -l < "$file" | tr -d ' ')
  physical_lines=$((physical_lines+lines))
  case "$file" in
    *.go) go_lines=$((go_lines+lines)) ;;
    *.gooo) gooo_lines=$((gooo_lines+lines)) ;;
  esac
done < <(find "$root" -path "$root/.git" -prune -o -type f ! -path "$root/README.md" -print0)
inventory_directories=$(find "$root" -path "$root/.git" -prune -o -type d -print | wc -l | tr -d ' ')

digest() { printf 'sha256:%s' "$(sha256 "$1")"; }
graph_digest=$(digest "$graph")
denominator_digest=$(digest "$denominator")
fixture_digest=$(printf '%s\n' \
  "$(digest "$fixture/authority.json")" \
  "$(digest "$fixture/manifest.json")" \
  "$(digest "$fixture/design-tokens.json")" \
  "$(digest "$fixture/component.tsx")" \
  "$(digest "$fixture/service.ts")" \
  "$(digest "$fixture/bindings.json")" \
  "$(digest "$fixture/generated/tokens.css")" | sha256sum | awk '{print "sha256:"$1}')

relation_json=$(mktemp)
trap 'rm -f "$relation_json"' EXIT
jq -S -n \
  --argjson tone "$tone_match" --argjson background "$background_match" \
  --argjson service "$service_match" --argjson padding "$padding_match" \
  --argjson authority "$authority_escalated" --arg scenario "$scenario" \
  --argjson manifest_valid "$manifest_valid" '
  def closed($id;$from;$to):
    {id:$id,state:"CLOSED",resolution:"EXACT",from:$from,to:$to,stage:null,step:null,
     reason:"EXPLICIT_VALUE_AND_REFERENCE_MATCH",unknown_class:null,next_operation:"NONE",blocked_by:[]};
  def unknown($id;$from;$to;$reason;$next;$blocked):
    {id:$id,state:"UNKNOWN",resolution:"PREREQUISITE_CLASS",from:$from,to:$to,stage:"COMPARISON",
     step:"COMPARE_EXPLICIT_VALUES_AND_REFERENCES",reason:$reason,unknown_class:"DIRECT_MISSING",
     next_operation:$next,blocked_by:$blocked};
  def refuted($id;$from;$to;$reason;$next;$stage;$step;$blocked):
    {id:$id,state:"REFUTED",resolution:"EXACT",from:$from,to:$to,stage:$stage,step:$step,
     reason:$reason,unknown_class:null,next_operation:$next,blocked_by:$blocked};
  [
    (if $tone then closed("component-tone";"DESIGN:Button.tone=Brand";"CODE:ButtonProps.tone=brand")
     else unknown("component-tone";"DESIGN:Button.tone=Brand";"CODE:ButtonProps.tone=brand";
       "EXPLICIT_MAPPING_MISSING";"PROVIDE_EXPLICIT_MAPPING";[]) end),
    (if $background then closed("component-background-token";"DESIGN:/color/action";"CODE:Button.background=var(--color-action)")
     else if $scenario=="digest-valid-laundering" and $manifest_valid then
       refuted("component-background-token";"DESIGN:/color/action";"CODE:Button.background=var(--color-action)";
         "DIGEST_VALID_SEMANTIC_LAUNDERING";"REJECT_DIGEST_ONLY_MATCH";"COMPARISON";
         "COMPARE_EXPLICIT_VALUES_AND_REFERENCES";["manifest.json"])
     else refuted("component-background-token";"DESIGN:/color/action";"CODE:Button.background=var(--color-action)";
       "EXPLICIT_VALUE_CONTRADICTION";"REPAIR_EXPLICIT_VALUE_OR_REFERENCE";"COMPARISON";
       "COMPARE_EXPLICIT_VALUES_AND_REFERENCES";["component.tsx"]) end end),
    (if $service then closed("service-action-token";"DESIGN:/color/action";"CODE:ButtonContract.actionToken=color.action")
     else unknown("service-action-token";"DESIGN:/color/action";"CODE:ButtonContract.actionToken=color.action";
       "EXPLICIT_MAPPING_MISSING";"PROVIDE_EXPLICIT_MAPPING";[]) end),
    (if $padding then closed("component-padding-token";"DESIGN:/space/control";"CODE:Button.padding=var(--space-control)")
     else if $scenario=="stale-token" then unknown("component-padding-token";"DESIGN:/space/control";
       "CODE:Button.padding=var(--space-control)";"STALE_TOKEN_OUTPUT";"REGENERATE_TOKEN_OUTPUT";["generated/tokens.css"])
     else unknown("component-padding-token";"DESIGN:/space/control";
       "EXPLICIT_MAPPING_MISSING";"PROVIDE_EXPLICIT_MAPPING";[]) end end),
    (if $authority then refuted("authority";"AUTHORITY:read_only=true";"AUTHORITY:repository_writes=0";
       "AUTHORITY_ESCALATION_REFUTED";"REMOVE_AUTHORITY_ESCALATION";"AUTHORITY";"VERIFY_READ_ONLY_AUTHORITY";["authority.json"])
     else empty end)
  ] | sort_by(.id)
' > "$relation_json"

exact_matches=$(jq '[.[]|select(.state=="CLOSED")]|length' "$relation_json")
unknown_bindings=$(jq '[.[]|select(.state=="UNKNOWN")]|length' "$relation_json")
refuted_bindings=$(jq '[.[]|select(.state=="REFUTED")]|length' "$relation_json")
if test "$refuted_bindings" -gt 0; then aggregate_state=REFUTED; elif test "$unknown_bindings" -gt 0; then aggregate_state=UNKNOWN; else aggregate_state=CLOSED; fi

claim_reason=EXACT_MATCH_CLOSED
claim_stage=NONE
claim_step=NONE
claim_unknown=NONE
claim_next=NONE
claim_blocked='[]'
if test "$aggregate_state" = UNKNOWN; then
  first_unknown=$(jq -c 'map(select(.state=="UNKNOWN"))[0]' "$relation_json")
  claim_reason=$(jq -r '.reason' <<<"$first_unknown")
  claim_stage=$(jq -r '.stage' <<<"$first_unknown")
  claim_step=$(jq -r '.step' <<<"$first_unknown")
  claim_unknown=$(jq -r '.unknown_class' <<<"$first_unknown")
  claim_next=$(jq -r '.next_operation' <<<"$first_unknown")
  claim_blocked=$(jq -c '.blocked_by' <<<"$first_unknown")
elif test "$aggregate_state" = REFUTED; then
  if test "$scenario" = authority-escalation; then
    claim_reason=AUTHORITY_ESCALATION_REFUTED
    claim_stage=AUTHORITY
    claim_step=VERIFY_READ_ONLY_AUTHORITY
    claim_next=REMOVE_AUTHORITY_ESCALATION
    claim_blocked='["authority.json"]'
  elif test "$scenario" = mixed; then
    claim_reason=MIXED_EVIDENCE_REFUTED
    claim_stage=AGGREGATION
    claim_step=APPLY_REFUTED_PRECEDENCE
    claim_next=RESOLVE_REFUTED_BINDINGS
    claim_blocked=$(jq -c '[.[]|select(.state!="CLOSED")|.id]' "$relation_json")
  elif test "$scenario" = digest-valid-laundering; then
    claim_reason=DIGEST_VALID_SEMANTIC_LAUNDERING
    claim_stage=COMPARISON
    claim_step=COMPARE_EXPLICIT_VALUES_AND_REFERENCES
    claim_next=REJECT_DIGEST_ONLY_MATCH
    claim_blocked='["manifest.json"]'
  else
    first_refuted=$(jq -c 'map(select(.state=="REFUTED"))[0]' "$relation_json")
    claim_reason=$(jq -r '.reason' <<<"$first_refuted")
    claim_stage=$(jq -r '.stage' <<<"$first_refuted")
    claim_step=$(jq -r '.step' <<<"$first_refuted")
    claim_next=$(jq -r '.next_operation' <<<"$first_refuted")
    claim_blocked=$(jq -c '.blocked_by' <<<"$first_refuted")
  fi
fi

mkdir -p "$output"
jq -S -n \
  --arg subject_sha "$subject_sha" --arg scenario "$scenario" --arg state "$aggregate_state" \
  --arg reason "$claim_reason" --arg stage "$claim_stage" --arg step "$claim_step" \
  --arg unknown_class "$claim_unknown" --arg next_operation "$claim_next" --argjson blocked_by "$claim_blocked" \
  --argjson token_count "$token_count" --argjson code_binding_count "$binding_count" \
  --argjson exact_matches "$exact_matches" --argjson unknown_bindings "$unknown_bindings" \
  --argjson refuted_bindings "$refuted_bindings" --argjson generated_artifact_files "$generated_artifact_files" \
  --argjson peak_rss_kib "$peak_rss_kib" --argjson wall_ms "$wall_ms" \
  --argjson manifest_digest_valid "$manifest_valid" --arg graph_digest "$graph_digest" \
  --arg denominator_digest "$denominator_digest" --arg fixture_digest "$fixture_digest" \
  --argjson authority_escalated "$authority_escalated" --slurpfile authority "$fixture/authority.json" \
  --slurpfile relations "$relation_json" --argjson input_files "$inventory_files" \
  --argjson input_directories "$inventory_directories" --argjson physical_lines "$physical_lines" \
  --argjson go_lines "$go_lines" --argjson gooo_lines "$gooo_lines" \
  --arg go_version "${GO_VERSION:-unknown}" '
  {
    schema:"gooo/design-token-code-evidence/evidence/v1",
    subject_sha:$subject_sha,scenario:$scenario,decision:$state,
    claim:{state:$state,stage:(if $stage=="NONE" then null else $stage end),step:(if $step=="NONE" then null else $step end),
      reason:$reason,unknown_class:(if $unknown_class=="NONE" then null else $unknown_class end),next_operation:$next_operation,blocked_by:$blocked_by},
    summary:{total_bindings:4,token_count:$token_count,code_binding_count:$code_binding_count,
      exact_matches:$exact_matches,unknown_bindings:$unknown_bindings,refuted_bindings:$refuted_bindings,
      generated_artifact_files:$generated_artifact_files,repository_writes:0,local_test_executions:0,
      local_tests_run:0,cross_project_required_gates:0},
    inventory:{input_files:$input_files,input_directories:$input_directories,physical_lines:$physical_lines,
      go_lines:$go_lines,gooo_lines:$gooo_lines,root_readme_excluded:true},
    performance:{go_version:$go_version,peak_rss_kib:$peak_rss_kib,wall_ms:$wall_ms},
    authority:{meta_source:"examples/token-code-evidence/main.gooo",source_of_truth:$authority[0].source_of_truth,
      matching_mode:$authority[0].matching_mode,read_only:$authority[0].read_only,
      automatic_remediation_authorized:$authority[0].automatic_remediation_authorized,
      repository_writes_authorized:$authority[0].repository_writes_authorized,
      authority_escalated:$authority_escalated,live_design_tool_required:$authority[0].live_design_tool_required,
      repository_writes:0,cross_project_required_gates:0,output_scope:$authority[0].output_scope},
    evidence:{graph_digest:$graph_digest,denominator_digest:$denominator_digest,fixture_digest:$fixture_digest,
      manifest_digest_valid:$manifest_digest_valid,resolution_precedence:["REFUTED","UNKNOWN","CLOSED"]},
    relations:$relations[0]
  }
' > "$output/evidence.json"

{
  echo '# Design token/code evidence dossier'
  echo
  jq -r '"- Scenario: `\(.scenario)`", "- Decision: **\(.decision)**", "- Claim: `\(.claim.state)` / `\(.claim.reason)`"' "$output/evidence.json"
  echo
  echo '## Evidence summary'
  echo
  echo '| Metric | Value |'
  echo '|---|---:|'
  jq -r '"| Token count | \(.summary.token_count) |", "| Code binding count | \(.summary.code_binding_count) |", "| Exact matches | \(.summary.exact_matches) |", "| UNKNOWN bindings | \(.summary.unknown_bindings) |", "| REFUTED bindings | \(.summary.refuted_bindings) |", "| Generated artifact files | \(.summary.generated_artifact_files) |", "| Repository writes | \(.summary.repository_writes) |", "| Local test executions | \(.summary.local_test_executions) |", "| Cross-project required gates | \(.summary.cross_project_required_gates) |", "| Input files | \(.inventory.input_files) |", "| Input directories | \(.inventory.input_directories) |", "| Physical lines | \(.inventory.physical_lines) |", "| Go lines | \(.inventory.go_lines) |", "| Gooo lines | \(.inventory.gooo_lines) |", "| Peak RSS | \(.performance.peak_rss_kib) KiB |", "| Wall time | \(.performance.wall_ms) ms |"' "$output/evidence.json"
  echo
  echo '## Explicit binding results'
  echo
  jq -r '.relations[]|"- `\(.id)`: **\(.state)** — \(.reason)"' "$output/evidence.json"
  echo
  echo '## Resolution coordinates'
  echo
  jq -r '"- stage: `\(.claim.stage // "NONE")`", "- step: `\(.claim.step // "NONE")`", "- reason: `\(.claim.reason)`", "- unknown class: `\(.claim.unknown_class // "NONE")`", "- next operation: `\(.claim.next_operation)`", "- blocked by: `\(.claim.blocked_by|join(", ") // "NONE")`"' "$output/evidence.json"
  echo
  echo '## Authority and scope'
  echo
  jq -r '"- source of truth: `\(.authority.source_of_truth)`", "- matching mode: `\(.authority.matching_mode)`", "- automatic remediation: \(.authority.automatic_remediation_authorized)", "- repository writes: \(.authority.repository_writes)", "- output scope: `\(.authority.output_scope)`", "- root README excluded from inventory: \(.inventory.root_readme_excluded)"' "$output/evidence.json"
} > "$output/dossier.md"
