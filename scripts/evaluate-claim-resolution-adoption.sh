#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 16; then
  echo "usage: evaluate-claim-resolution-adoption.sh GRAPH DENOMINATOR CLOSED MISSING NAME_ONLY REFUTED INVALID_UNKNOWN INVALID_STATE MATCHER_NORMAL MATCHER_UNKNOWN MATCHER_NAME MATCHER_REFUTED REPLAY OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 2
fi

graph=$1
denominator=$2
closed_receipt=$3
missing_receipt=$4
name_receipt=$5
refuted_receipt=$6
invalid_unknown_receipt=$7
invalid_state_receipt=$8
matcher_normal=$9
matcher_unknown=${10}
matcher_name=${11}
matcher_refuted=${12}
replay=${13}
output=${14}
subject_sha=${15}
scenario=${16}

for file in "$graph" "$denominator" "$closed_receipt" "$missing_receipt" "$name_receipt" "$refuted_receipt" "$invalid_unknown_receipt" "$invalid_state_receipt" "$matcher_normal" "$matcher_unknown" "$matcher_name" "$matcher_refuted" "$replay"; do
  test -f "$file" || { echo "missing required input: $file" >&2; exit 2; }
done

jq -e '
  .schema=="gooo/design-evidence/claim-resolution-adoption-denominator/v1" and
  .candidate_id=="gooo.primitive.claim-resolution-tuple.v1" and
  .total==12 and (.cells|length)==12 and
  ([.proofs[].total]|add)==12 and ([.indicator_classes[].total]|add)==12
' "$denominator" >/dev/null

jq -e --slurpfile denominator "$denominator" '
  . as $graph |
  .schema_version=="gooo-graph/v1" and
  ([$graph.nodes[]|select(.kind=="Activity")]|length)==12 and
  ([$denominator[0].cells[] as $cell |
    select(([$graph.nodes[]|select(.kind=="Activity" and .name==$cell.activity)]|length)==1)
  ]|length)==12
' "$graph" >/dev/null

validate_receipt() {
  file=$1 activity=$2 state=$3 stage=$4 step=$5 reason=$6 unknown_class=$7 next_operation=$8
  jq -e --arg activity "$activity" --arg state "$state" --arg stage "$stage" --arg step "$step" \
    --arg reason "$reason" --arg unknown_class "$unknown_class" --arg next_operation "$next_operation" '
    .schema=="gooo/claim-resolution/v1" and
    .candidate_id=="gooo.primitive.claim-resolution-tuple.v1" and
    .decision=="CLAIM_RESOLUTION_OBSERVED" and
    .subject.activity==$activity and .subject.activity_occurrences==1 and
    .subject.binding=="GOOO_ACTIVITY_VALUE_PROGRAM" and
    .contract.version=="v1" and (.contract.base_fields|length)==6 and
    .contract.states==["CLOSED","UNKNOWN","REFUTED"] and
    .claim.state==$state and
    .claim.stage==(if $stage=="NONE" then null else $stage end) and
    .claim.step==(if $step=="NONE" then null else $step end) and
    .claim.reason==$reason and
    .claim.unknown_class==(if $unknown_class=="NONE" then null else $unknown_class end) and
    .claim.next_operation==$next_operation and
    .summary.fields_observed==6 and .summary.fields_total==6 and
    .summary.resolutions_observed==1 and .summary.resolutions_total==1 and
    .summary.repository_writes==0 and (.indicators|length)==4 and
    all(.indicators[];.activity==$activity) and
    .authority.source=="GOOO_ACTIVITY_VALUE_PROGRAM" and
    .authority.core_mutation_authorized==false and .authority.repository_writes==0
  ' "$file" >/dev/null
}

validate_invalid_receipt() {
  file=$1 activity=$2 reason=$3 next_operation=$4
  jq -e --arg activity "$activity" --arg reason "$reason" --arg next_operation "$next_operation" '
    .schema=="gooo/claim-resolution/v1" and
    .candidate_id=="gooo.primitive.claim-resolution-tuple.v1" and
    .decision=="FAIL_CLOSED" and .subject.activity==$activity and
    .subject.activity_occurrences==1 and .claim.state=="REFUTED" and
    .claim.stage=="CLAIM_RESOLUTION" and .claim.step=="PARSE_CLAIM_RESOLUTION_TUPLE" and
    .claim.reason==$reason and .claim.unknown_class==null and
    .claim.next_operation==$next_operation and
    .summary.fields_observed==6 and .summary.fields_total==6 and
    .summary.resolutions_observed==0 and .summary.repository_writes==0
  ' "$file" >/dev/null
}

validate_matcher_claim() {
  file=$1 decision=$2 state=$3 stage=$4 step=$5 reason=$6 unknown_class=$7 next_operation=$8
  jq -e --arg decision "$decision" --arg state "$state" --arg stage "$stage" --arg step "$step" \
    --arg reason "$reason" --arg unknown_class "$unknown_class" --arg next_operation "$next_operation" '
    .schema=="gooo/design-code-match-report/v1" and .decision==$decision and
    .claim.state==$state and .claim.stage==(if $stage=="NONE" then null else $stage end) and
    .claim.step==(if $step=="NONE" then null else $step end) and .claim.reason==$reason and
    .claim.unknown_class==(if $unknown_class=="NONE" then null else $unknown_class end) and
    .claim.next_operation==$next_operation
  ' "$file" >/dev/null
}

compare_claim() {
  matcher=$1 receipt=$2
  jq -e --slurpfile receipt "$receipt" '
    (.claim|{state,stage,step,reason,unknown_class,next_operation}) ==
    ($receipt[0].claim|{state,stage,step,reason,unknown_class,next_operation})
  ' "$matcher" >/dev/null
}

validate_valid_receipts() {
  validate_receipt "$closed_receipt" ResolveDesignClosedClaim CLOSED NONE NONE DESIGN_CODE_RELATIONS_OBSERVED NONE NONE
  validate_receipt "$missing_receipt" ResolveMissingEvidenceUnknown UNKNOWN RELATION RESOLVE_DESIGN_CODE_RELATION CODE_CONNECT_PROPERTY_UNAVAILABLE DIRECT_MISSING PROVIDE_CODE_CONNECT_PROPERTY
  validate_receipt "$name_receipt" ResolveNameOnlyUnknown UNKNOWN RELATION RESOLVE_DESIGN_CODE_RELATION NAME_ONLY_MATCH_FORBIDDEN DIRECT_MISSING PROVIDE_EXPLICIT_LINEAGE_EDGE
  validate_receipt "$refuted_receipt" ResolveDesignContradiction REFUTED RELATION RESOLVE_DESIGN_CODE_RELATION DTCG_ALIAS_TARGET_MISSING NONE REPAIR_DESIGN_EVIDENCE
}

validate_matchers() {
  validate_matcher_claim "$matcher_normal" DESIGN_CODE_RELATIONS_OBSERVED CLOSED NONE NONE DESIGN_CODE_RELATIONS_OBSERVED NONE NONE
  validate_matcher_claim "$matcher_unknown" DESIGN_CODE_MATCH_UNKNOWN UNKNOWN RELATION RESOLVE_DESIGN_CODE_RELATION CODE_CONNECT_PROPERTY_UNAVAILABLE DIRECT_MISSING PROVIDE_CODE_CONNECT_PROPERTY
  validate_matcher_claim "$matcher_name" DESIGN_CODE_MATCH_UNKNOWN UNKNOWN RELATION RESOLVE_DESIGN_CODE_RELATION NAME_ONLY_MATCH_FORBIDDEN DIRECT_MISSING PROVIDE_EXPLICIT_LINEAGE_EDGE
  validate_matcher_claim "$matcher_refuted" FAIL_CLOSED REFUTED RELATION RESOLVE_DESIGN_CODE_RELATION DTCG_ALIAS_TARGET_MISSING NONE REPAIR_DESIGN_EVIDENCE
}

validate_comparisons() {
  compare_claim "$matcher_normal" "$closed_receipt"
  compare_claim "$matcher_unknown" "$missing_receipt"
  compare_claim "$matcher_name" "$name_receipt"
  compare_claim "$matcher_refuted" "$refuted_receipt"
}

validate_replay() {
  jq -e '.schema=="gooo/design-evidence/claim-resolution-replay/v1" and .receipts_compared==6 and .receipts_equal==6 and .deterministic==true' "$replay" >/dev/null
}

digest() {
  printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"
}

case "$scenario" in
  complete)
    validate_valid_receipts
    validate_invalid_receipt "$invalid_unknown_receipt" RejectIncompleteUnknown UNKNOWN_TUPLE_INCOMPLETE PROVIDE_COMPLETE_UNKNOWN_TUPLE
    validate_invalid_receipt "$invalid_state_receipt" RejectUnrecognizedState CLAIM_STATE_UNKNOWN RESTORE_CLOSED_UNKNOWN_OR_REFUTED_STATE
    validate_matchers
    validate_comparisons
    validate_replay
    ;;
  missing-receipt)
    jq -e '.==null' "$missing_receipt" >/dev/null
    validate_receipt "$closed_receipt" ResolveDesignClosedClaim CLOSED NONE NONE DESIGN_CODE_RELATIONS_OBSERVED NONE NONE
    validate_receipt "$name_receipt" ResolveNameOnlyUnknown UNKNOWN RELATION RESOLVE_DESIGN_CODE_RELATION NAME_ONLY_MATCH_FORBIDDEN DIRECT_MISSING PROVIDE_EXPLICIT_LINEAGE_EDGE
    validate_receipt "$refuted_receipt" ResolveDesignContradiction REFUTED RELATION RESOLVE_DESIGN_CODE_RELATION DTCG_ALIAS_TARGET_MISSING NONE REPAIR_DESIGN_EVIDENCE
    validate_invalid_receipt "$invalid_unknown_receipt" RejectIncompleteUnknown UNKNOWN_TUPLE_INCOMPLETE PROVIDE_COMPLETE_UNKNOWN_TUPLE
    validate_invalid_receipt "$invalid_state_receipt" RejectUnrecognizedState CLAIM_STATE_UNKNOWN RESTORE_CLOSED_UNKNOWN_OR_REFUTED_STATE
    validate_matchers
    validate_replay
    ;;
  matcher-claim-tamper)
    validate_valid_receipts
    validate_invalid_receipt "$invalid_unknown_receipt" RejectIncompleteUnknown UNKNOWN_TUPLE_INCOMPLETE PROVIDE_COMPLETE_UNKNOWN_TUPLE
    validate_invalid_receipt "$invalid_state_receipt" RejectUnrecognizedState CLAIM_STATE_UNKNOWN RESTORE_CLOSED_UNKNOWN_OR_REFUTED_STATE
    jq -e '.claim.unknown_class=="CONTEXT_MISSING"' "$matcher_unknown" >/dev/null
    validate_matcher_claim "$matcher_normal" DESIGN_CODE_RELATIONS_OBSERVED CLOSED NONE NONE DESIGN_CODE_RELATIONS_OBSERVED NONE NONE
    validate_matcher_claim "$matcher_name" DESIGN_CODE_MATCH_UNKNOWN UNKNOWN RELATION RESOLVE_DESIGN_CODE_RELATION NAME_ONLY_MATCH_FORBIDDEN DIRECT_MISSING PROVIDE_EXPLICIT_LINEAGE_EDGE
    validate_matcher_claim "$matcher_refuted" FAIL_CLOSED REFUTED RELATION RESOLVE_DESIGN_CODE_RELATION DTCG_ALIAS_TARGET_MISSING NONE REPAIR_DESIGN_EVIDENCE
    validate_replay
    ;;
  invalid-core-decision)
    validate_valid_receipts
    validate_invalid_receipt "$invalid_unknown_receipt" RejectIncompleteUnknown UNKNOWN_TUPLE_INCOMPLETE PROVIDE_COMPLETE_UNKNOWN_TUPLE
    jq -e '.decision=="CLAIM_RESOLUTION_OBSERVED" and .claim.reason=="CLAIM_STATE_UNKNOWN"' "$invalid_state_receipt" >/dev/null
    validate_matchers
    validate_comparisons
    validate_replay
    ;;
  scope-escalation)
    jq -e '.decision=="CLAIM_RESOLUTION_OBSERVED" and .authority.repository_writes==1' "$closed_receipt" >/dev/null
    validate_receipt "$missing_receipt" ResolveMissingEvidenceUnknown UNKNOWN RELATION RESOLVE_DESIGN_CODE_RELATION CODE_CONNECT_PROPERTY_UNAVAILABLE DIRECT_MISSING PROVIDE_CODE_CONNECT_PROPERTY
    validate_receipt "$name_receipt" ResolveNameOnlyUnknown UNKNOWN RELATION RESOLVE_DESIGN_CODE_RELATION NAME_ONLY_MATCH_FORBIDDEN DIRECT_MISSING PROVIDE_EXPLICIT_LINEAGE_EDGE
    validate_receipt "$refuted_receipt" ResolveDesignContradiction REFUTED RELATION RESOLVE_DESIGN_CODE_RELATION DTCG_ALIAS_TARGET_MISSING NONE REPAIR_DESIGN_EVIDENCE
    validate_invalid_receipt "$invalid_unknown_receipt" RejectIncompleteUnknown UNKNOWN_TUPLE_INCOMPLETE PROVIDE_COMPLETE_UNKNOWN_TUPLE
    validate_invalid_receipt "$invalid_state_receipt" RejectUnrecognizedState CLAIM_STATE_UNKNOWN RESTORE_CLOSED_UNKNOWN_OR_REFUTED_STATE
    validate_matchers
    validate_replay
    ;;
  *)
    echo "unsupported scenario: $scenario" >&2
    exit 2
    ;;
esac

jq -S -n \
  --slurpfile denominator "$denominator" \
  --slurpfile closed "$closed_receipt" --slurpfile missing "$missing_receipt" \
  --slurpfile name "$name_receipt" --slurpfile refuted "$refuted_receipt" \
  --slurpfile invalid_unknown "$invalid_unknown_receipt" --slurpfile invalid_state "$invalid_state_receipt" \
  --arg scenario "$scenario" --arg subject_sha "$subject_sha" \
  --arg graph_digest "$(digest "$graph")" --arg denominator_digest "$(digest "$denominator")" \
  --arg closed_digest "$(digest "$closed_receipt")" --arg missing_digest "$(digest "$missing_receipt")" \
  --arg name_digest "$(digest "$name_receipt")" --arg refuted_digest "$(digest "$refuted_receipt")" \
  --arg invalid_unknown_digest "$(digest "$invalid_unknown_receipt")" --arg invalid_state_digest "$(digest "$invalid_state_receipt")" \
  --arg replay_digest "$(digest "$replay")" '
  $denominator[0] as $d |
  [$d.cells[] |
    {id,activity,proof_choice,indicator_class,state:"CLOSED",stage:null,step:null,
      reason:.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]} |
    if $scenario=="missing-receipt" and .id=="MISSING_EVIDENCE_UNKNOWN_RESOLVED" then
      .+{state:"UNKNOWN",stage:"CORE_RECEIPT",step:"RESOLVE_MISSING_EVIDENCE_UNKNOWN",
        reason:"CORE_CLAIM_RESOLUTION_RECEIPT_UNAVAILABLE",unknown_class:"DIRECT_MISSING",
        next_operation:"PROVIDE_CORE_CLAIM_RESOLUTION_RECEIPT",blocked_by:["ResolveMissingEvidenceUnknown"]}
    elif $scenario=="missing-receipt" and (.id=="MATCHER_CLAIMS_COMPARED" or .id=="INDEPENDENT_ADOPTION_RECORDED") then
      .+{state:"UNKNOWN",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_BLOCKED",
        unknown_class:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_CORE_CLAIM_RECEIPT",
        blocked_by:["MISSING_EVIDENCE_UNKNOWN_RESOLVED"]}
    elif $scenario=="matcher-claim-tamper" and .id=="MATCHER_CLAIMS_COMPARED" then
      .+{state:"REFUTED",stage:"CLAIM_COMPARISON",step:"COMPARE_MATCHER_AND_CORE_CLAIMS",
        reason:"MATCHER_CORE_CLAIM_MISMATCH",next_operation:"RESTORE_MATCHER_CLAIM_FIELDS",
        blocked_by:["matcher-unknown.json"]}
    elif $scenario=="invalid-core-decision" and .id=="UNRECOGNIZED_STATE_REJECTED" then
      .+{state:"REFUTED",stage:"CORE_DECISION",step:"REJECT_UNRECOGNIZED_STATE",
        reason:"INVALID_CORE_CLAIM_DECISION",next_operation:"RESTORE_FAIL_CLOSED_CORE_DECISION",
        blocked_by:["RejectUnrecognizedState"]}
    elif $scenario=="scope-escalation" and .id=="INDEPENDENT_ADOPTION_RECORDED" then
      .+{state:"REFUTED",stage:"AUTHORITY",step:"RECORD_INDEPENDENT_ADOPTION",
        reason:"CORE_REPOSITORY_WRITE_AUTHORITY_ESCALATION",next_operation:"RESTORE_READ_ONLY_CORE_AUTHORITY",
        blocked_by:["ResolveDesignClosedClaim"]}
    else . end
  ] as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed_count |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  (([$cells[]|select(.state=="REFUTED")][0]) // ([$cells[]|select(.state=="UNKNOWN")][0])) as $first |
  (if $scenario=="complete" then 4 elif $scenario=="missing-receipt" then 3 else 4 end) as $resolved_scenarios |
  (if $scenario=="matcher-claim-tamper" then 3 elif $scenario=="missing-receipt" then 3 else 4 end) as $matched_claims |
  (if $scenario=="invalid-core-decision" then 1 else 2 end) as $rejections |
  {
    schema:"gooo/design-evidence/claim-resolution-adoption-report/v1",
    scenario:$scenario,subject_sha:$subject_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "CLAIM_RESOLUTION_ADOPTION_UNKNOWN" else "CLAIM_RESOLUTION_ADOPTION_OBSERVED" end),
    candidate:{id:$d.candidate_id,state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "ADOPTED" end),
      implementation_status:(if $scenario=="complete" then "INDEPENDENT_CONSUMER_ADOPTION_OBSERVED" else "NOT_COUNTED" end)},
    claim:(if $first==null then
      {state:"CLOSED",stage:null,step:null,reason:"DESIGN_CLAIM_RESOLUTION_ADOPTION_OBSERVED",
        unknown_class:null,next_operation:"PUBLISH_DESIGN_CLAIM_RESOLUTION_ADOPTION",blocked_by:[]}
      else {state:$first.state,stage:$first.stage,step:$first.step,reason:$first.reason,
        unknown_class:$first.unknown_class,next_operation:$first.next_operation,blocked_by:$first.blocked_by} end),
    summary:{total_cells:12,closed_cells:$closed_count,unknown_cells:$unknown_count,refuted_cells:$refuted_count,
      claim_scenarios_total:4,claim_scenarios_resolved:$resolved_scenarios,
      matcher_claims_total:4,matcher_claims_matched:$matched_claims,
      rejection_scenarios_total:2,rejection_scenarios_observed:$rejections,
      claim_fields_total:24,claim_fields_observed:($resolved_scenarios*6),
      independent_consumer_adoptions:(if $scenario=="complete" then 1 else 0 end),
      repository_writes:0,local_tests_run:0,cross_project_required_gates:0},
    authority:{core_release:"v0.3.0-dev",matcher_release:"v0.5.0-dev",
      resolution_source:"GOOO_ACTIVITY_VALUE_PROGRAM",core_mutation_authorized:false,
      dependency_propagation_authorized:false,automatic_merge_authorized:false},
    evidence:{graph_digest:$graph_digest,denominator_digest:$denominator_digest,
      closed_digest:$closed_digest,missing_digest:$missing_digest,name_digest:$name_digest,
      refuted_digest:$refuted_digest,invalid_unknown_digest:$invalid_unknown_digest,
      invalid_state_digest:$invalid_state_digest,replay_digest:$replay_digest},
    cells:$cells,
    proofs:[$d.proofs[] as $proof | {choice:$proof.choice,total:$proof.total,
      closed:([$cells[]|select(.proof_choice==$proof.choice and .state=="CLOSED")]|length)}],
    indicator_classes:[$d.indicator_classes[] as $indicator | {class:$indicator.class,total:$indicator.total,
      closed:([$cells[]|select(.indicator_class==$indicator.class and .state=="CLOSED")]|length)}]
  }
' > "$output"
