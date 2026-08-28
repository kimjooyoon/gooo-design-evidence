#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 14; then
  echo "usage: generate-design-review-packet.sh GRAPH DENOMINATOR REQUEST MATCHER_DIR ADOPTION_DIR READY_RECEIPT UNKNOWN_RECEIPT TUPLE_REFUTED_RECEIPT MISMATCH_REFUTED_RECEIPT AUTHORITY_REFUTED_RECEIPT OUTPUT_JSON OUTPUT_MD SUBJECT_SHA SCENARIO" >&2
  exit 2
fi

graph=$1
denominator=$2
request=$3
matcher_dir=$4
adoption_dir=$5
ready_receipt=$6
unknown_receipt=$7
tuple_refuted_receipt=$8
mismatch_refuted_receipt=$9
authority_refuted_receipt=${10}
output_json=${11}
output_md=${12}
subject_sha=${13}
scenario=${14}

matcher_normal="$matcher_dir/matcher-normal.json"
matcher_conformance="$matcher_dir/matcher-conformance.json"
adoption_report="$adoption_dir/adoption-report.json"
claim_closed="$adoption_dir/claim-closed.json"
claim_missing="$adoption_dir/claim-missing.json"
claim_name="$adoption_dir/claim-name-only.json"
claim_refuted="$adoption_dir/claim-refuted.json"

for file in "$graph" "$denominator" "$request" "$matcher_normal" "$matcher_conformance" "$adoption_report" \
  "$claim_closed" "$claim_missing" "$claim_name" "$claim_refuted" "$ready_receipt" "$unknown_receipt" \
  "$tuple_refuted_receipt" "$mismatch_refuted_receipt" "$authority_refuted_receipt"; do
  test -f "$file" || { echo "missing review packet input: $file" >&2; exit 2; }
done

case "$scenario" in
  complete|missing-matcher-report|claim-tuple-tamper|unreviewed-mismatch|authority-escalation) ;;
  *) echo "unsupported review packet scenario: $scenario" >&2; exit 2 ;;
esac

jq -e '
  .schema=="gooo/design-evidence/review-packet-denominator/v1" and
  .candidate_id=="gooo.product.design-release-review-packet.v1" and
  .total==15 and (.cells|length)==15 and
  ([.proofs[].total]|add)==15 and ([.indicator_classes[].total]|add)==15
' "$denominator" >/dev/null

jq -e --slurpfile denominator "$denominator" '
  . as $graph |
  .schema_version=="gooo-graph/v1" and
  ([$graph.nodes[]|select(.kind=="Activity")]|length)==15 and
  ([$denominator[0].cells[] as $cell |
    select(([$graph.nodes[]|select(.kind=="Activity" and .name==$cell.activity)]|length)==1)
  ]|length)==15
' "$graph" >/dev/null

validate_request() {
  local expected_auto_merge=$1
  jq -e --argjson expected_auto_merge "$expected_auto_merge" '
    .schema=="gooo/design-release-review-request/v1" and
    .request_id=="button-system-v1-release-review" and .component=="Button" and
    .owner=="design-system" and .reviewer=="frontend-platform" and
    (.required_relation_ids|sort)==["action-token-used-by-button","figma-disabled-implemented-by-code","figma-variant-implemented-by-code","ios-radius-intentional-difference"] and
    (.required_claim_activities|sort)==["ResolveDesignClosedClaim","ResolveDesignContradiction","ResolveMissingEvidenceUnknown","ResolveNameOnlyUnknown"] and
    .required_outputs==["design-review-packet.json","design-review-packet.md"] and
    .policy=={allowed_reviewed_mismatches:1,allowed_unresolved_mismatches:0,required_matches:3} and
    .authority.automatic_merge_authorized==$expected_auto_merge and
    .authority.repository_writes_authorized==false and .authority.live_figma_required==false
  ' "$request" >/dev/null
}

validate_meta_receipt() {
  local file=$1 activity=$2 state=$3 stage=$4 step=$5 reason=$6 unknown_class=$7 next_operation=$8
  jq -e --arg activity "$activity" --arg state "$state" --arg stage "$stage" --arg step "$step" \
    --arg reason "$reason" --arg unknown_class "$unknown_class" --arg next_operation "$next_operation" '
    .schema=="gooo/claim-resolution/v1" and .decision=="CLAIM_RESOLUTION_OBSERVED" and
    .subject.activity==$activity and .subject.activity_occurrences==1 and
    .subject.binding=="GOOO_ACTIVITY_VALUE_PROGRAM" and
    .claim.state==$state and .claim.stage==(if $stage=="NONE" then null else $stage end) and
    .claim.step==(if $step=="NONE" then null else $step end) and .claim.reason==$reason and
    .claim.unknown_class==(if $unknown_class=="NONE" then null else $unknown_class end) and
    .claim.next_operation==$next_operation and .summary.fields_observed==6 and
    .summary.fields_total==6 and .summary.repository_writes==0 and
    .authority.source=="GOOO_ACTIVITY_VALUE_PROGRAM" and .authority.core_mutation_authorized==false
  ' "$file" >/dev/null
}

validate_released_receipt() {
  local file=$1 activity=$2 state=$3 reason=$4 unknown_class=$5 next_operation=$6
  jq -e --arg activity "$activity" --arg state "$state" --arg reason "$reason" \
    --arg unknown_class "$unknown_class" --arg next_operation "$next_operation" '
    .schema=="gooo/claim-resolution/v1" and .decision=="CLAIM_RESOLUTION_OBSERVED" and
    .subject.activity==$activity and .subject.binding=="GOOO_ACTIVITY_VALUE_PROGRAM" and
    .claim.state==$state and .claim.reason==$reason and
    .claim.unknown_class==(if $unknown_class=="NONE" then null else $unknown_class end) and
    .claim.next_operation==$next_operation and .summary.fields_observed==6 and .summary.fields_total==6
  ' "$file" >/dev/null
}

validate_meta_receipt "$ready_receipt" ResolveReviewReadyClaim CLOSED NONE NONE DESIGN_RELEASE_REVIEW_PACKET_GENERATED NONE PUBLISH_IMMUTABLE_DESIGN_REVIEW_PACKET_RELEASE
validate_meta_receipt "$unknown_receipt" PreserveMissingMatcherUnknown UNKNOWN RELEASE_EVIDENCE OBSERVE_RELEASED_MATCHER_EVIDENCE MATCHER_RELEASE_REPORT_UNAVAILABLE DIRECT_MISSING RESTORE_MATCHER_RELEASE_REPORT
validate_meta_receipt "$tuple_refuted_receipt" RefuteClaimTupleMismatch REFUTED CLAIM_COMPARISON PROJECT_CLAIM_TUPLE_LEDGER RELEASED_CLAIM_TUPLE_MISMATCH NONE RESTORE_RELEASED_CLAIM_TUPLES
validate_meta_receipt "$mismatch_refuted_receipt" RefuteUnreviewedMismatch REFUTED RELATION_POLICY PROJECT_RELATION_DISPOSITIONS UNREVIEWED_DESIGN_MISMATCH NONE REVIEW_OR_REPAIR_DESIGN_MISMATCH
validate_meta_receipt "$authority_refuted_receipt" RefuteAuthorityEscalation REFUTED AUTHORITY BIND_REVIEW_AUTHORITY AUTOMATIC_MERGE_AUTHORITY_ESCALATED NONE REMOVE_AUTOMATIC_MERGE_AUTHORITY

jq -e '
  .schema=="gooo/design-code-match-conformance/v1" and .decision=="DESIGN_CODE_MATCHER_CONFORMANT" and
  .summary.closed_cells==12 and .summary.total_cells==12 and .summary.relation_outputs==4 and
  .summary.match==3 and .summary.reviewed_mismatches==1 and .summary.unknown_relations==0 and
  .summary.repository_writes==0 and .summary.cross_project_required_gates==0
' "$matcher_conformance" >/dev/null
jq -e '
  .schema=="gooo/design-evidence/claim-resolution-adoption-report/v1" and
  .decision=="CLAIM_RESOLUTION_ADOPTION_OBSERVED" and .summary.closed_cells==12 and
  .summary.claim_scenarios_resolved==4 and .summary.claim_fields_observed==24 and
  .summary.repository_writes==0 and .summary.cross_project_required_gates==0
' "$adoption_report" >/dev/null

validate_released_receipt "$claim_closed" ResolveDesignClosedClaim CLOSED DESIGN_CODE_RELATIONS_OBSERVED NONE NONE
if test "$scenario" = claim-tuple-tamper; then
  validate_released_receipt "$claim_missing" ResolveMissingEvidenceUnknown UNKNOWN CODE_CONNECT_PROPERTY_UNAVAILABLE CONTEXT_MISSING PROVIDE_CODE_CONNECT_PROPERTY
else
  validate_released_receipt "$claim_missing" ResolveMissingEvidenceUnknown UNKNOWN CODE_CONNECT_PROPERTY_UNAVAILABLE DIRECT_MISSING PROVIDE_CODE_CONNECT_PROPERTY
fi
validate_released_receipt "$claim_name" ResolveNameOnlyUnknown UNKNOWN NAME_ONLY_MATCH_FORBIDDEN DIRECT_MISSING PROVIDE_EXPLICIT_LINEAGE_EDGE
validate_released_receipt "$claim_refuted" ResolveDesignContradiction REFUTED DTCG_ALIAS_TARGET_MISSING NONE REPAIR_DESIGN_EVIDENCE

case "$scenario" in
  missing-matcher-report)
    validate_request false
    jq -e '.==null' "$matcher_normal" >/dev/null
    resolution=$unknown_receipt
    ;;
  unreviewed-mismatch)
    validate_request false
    jq -e '
      .schema=="gooo/design-code-match-report/v1" and .decision=="FAIL_CLOSED" and
      .claim.state=="REFUTED" and .claim.reason=="INTENTIONAL_DIFFERENCE_UNREVIEWED" and
      .summary.match==3 and .summary.mismatch==1 and .summary.reviewed_mismatches==0 and
      .summary.unresolved_mismatches==1 and
      ([.relations[]|select(.id=="ios-radius-intentional-difference" and .disposition=="UNRESOLVED_CONTRADICTION")]|length)==1
    ' "$matcher_normal" >/dev/null
    resolution=$mismatch_refuted_receipt
    ;;
  authority-escalation)
    validate_request true
    jq -e '.decision=="DESIGN_CODE_RELATIONS_OBSERVED" and .summary.match==3 and .summary.reviewed_mismatches==1' "$matcher_normal" >/dev/null
    resolution=$authority_refuted_receipt
    ;;
  claim-tuple-tamper)
    validate_request false
    jq -e '.decision=="DESIGN_CODE_RELATIONS_OBSERVED" and .summary.match==3 and .summary.reviewed_mismatches==1' "$matcher_normal" >/dev/null
    resolution=$tuple_refuted_receipt
    ;;
  complete)
    validate_request false
    jq -e '.decision=="DESIGN_CODE_RELATIONS_OBSERVED" and .summary.match==3 and .summary.reviewed_mismatches==1 and .summary.unresolved_mismatches==0' "$matcher_normal" >/dev/null
    resolution=$ready_receipt
    ;;
esac

digest() {
  printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"
}

jq -S -n \
  --slurpfile denominator "$denominator" --slurpfile request "$request" \
  --slurpfile matcher "$matcher_normal" --slurpfile matcher_conformance "$matcher_conformance" \
  --slurpfile adoption "$adoption_report" --slurpfile claim_closed "$claim_closed" \
  --slurpfile claim_missing "$claim_missing" --slurpfile claim_name "$claim_name" \
  --slurpfile claim_refuted "$claim_refuted" --slurpfile resolution "$resolution" \
  --slurpfile ready "$ready_receipt" --slurpfile missing "$unknown_receipt" \
  --slurpfile tuple_refuted "$tuple_refuted_receipt" --slurpfile mismatch_refuted "$mismatch_refuted_receipt" \
  --slurpfile authority_refuted "$authority_refuted_receipt" \
  --arg scenario "$scenario" --arg subject_sha "$subject_sha" \
  --arg graph_digest "$(digest "$graph")" --arg denominator_digest "$(digest "$denominator")" \
  --arg request_digest "$(digest "$request")" --arg matcher_digest "$(digest "$matcher_normal")" \
  --arg matcher_conformance_digest "$(digest "$matcher_conformance")" --arg adoption_digest "$(digest "$adoption_report")" \
  --arg claim_closed_digest "$(digest "$claim_closed")" --arg claim_missing_digest "$(digest "$claim_missing")" \
  --arg claim_name_digest "$(digest "$claim_name")" --arg claim_refuted_digest "$(digest "$claim_refuted")" '
  $denominator[0] as $d |
  $request[0] as $request |
  ($matcher[0] // {relations:[]}) as $matcher |
  [$matcher.relations[] |
    . + {review_action:(if .state=="MATCH" then "PRESERVE_EXPLICIT_BINDING"
      elif .disposition=="REVIEWED_DIFFERENCE" then "PRESERVE_REVIEWED_EXCEPTION"
      elif .state=="UNKNOWN" then .next_operation else "REVIEW_OR_REPAIR_DESIGN_MISMATCH" end)}
  ] as $relations |
  [$claim_closed[0],$claim_missing[0],$claim_name[0],$claim_refuted[0] |
    {activity:.subject.activity,claim:.claim,fields_observed:.summary.fields_observed,
      binding:.subject.binding,source_digest:.subject.source_digest}
  ] | sort_by(.activity) as $claim_tuples |
  [$ready[0],$missing[0],$tuple_refuted[0],$mismatch_refuted[0],$authority_refuted[0] |
    {activity:.subject.activity,claim:.claim,fields_observed:.summary.fields_observed,binding:.subject.binding}
  ] | sort_by(.activity) as $decision_receipts |
  [$d.cells[] | .id as $cell_id |
    {id,activity,proof_choice,indicator_class,state:"CLOSED",stage:null,step:null,
      reason:.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]} |
    if $scenario=="missing-matcher-report" and $cell_id=="RELEASED_MATCHER_EVIDENCE" then
      .+{state:"UNKNOWN",stage:"RELEASE_EVIDENCE",step:"OBSERVE_RELEASED_MATCHER_EVIDENCE",
        reason:"MATCHER_RELEASE_REPORT_UNAVAILABLE",unknown_class:"DIRECT_MISSING",
        next_operation:"RESTORE_MATCHER_RELEASE_REPORT",blocked_by:["matcher-normal.json"]}
    elif $scenario=="missing-matcher-report" and (["RELATION_DISPOSITIONS","MACHINE_REVIEW_PACKET","HUMAN_REVIEW_PACKET","REVIEW_READY_DECISION"]|index($cell_id))!=null then
      .+{state:"UNKNOWN",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_EVIDENCE_UNAVAILABLE",
        unknown_class:"DEPENDENCY_BLOCKED",next_operation:"RESTORE_MATCHER_RELEASE_REPORT",
        blocked_by:["RELEASED_MATCHER_EVIDENCE"]}
    elif $scenario=="claim-tuple-tamper" and $cell_id=="CLAIM_TUPLE_LEDGER" then
      .+{state:"REFUTED",stage:"CLAIM_COMPARISON",step:"PROJECT_CLAIM_TUPLE_LEDGER",
        reason:"RELEASED_CLAIM_TUPLE_MISMATCH",next_operation:"RESTORE_RELEASED_CLAIM_TUPLES",
        blocked_by:["claim-missing.json"]}
    elif $scenario=="claim-tuple-tamper" and (["MACHINE_REVIEW_PACKET","HUMAN_REVIEW_PACKET","REVIEW_READY_DECISION"]|index($cell_id))!=null then
      .+{state:"REFUTED",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_REFUTED",
        next_operation:"RESTORE_RELEASED_CLAIM_TUPLES",blocked_by:["CLAIM_TUPLE_LEDGER"]}
    elif $scenario=="unreviewed-mismatch" and $cell_id=="RELATION_DISPOSITIONS" then
      .+{state:"REFUTED",stage:"RELATION_POLICY",step:"PROJECT_RELATION_DISPOSITIONS",
        reason:"UNREVIEWED_DESIGN_MISMATCH",next_operation:"REVIEW_OR_REPAIR_DESIGN_MISMATCH",
        blocked_by:["ios-radius-intentional-difference"]}
    elif $scenario=="unreviewed-mismatch" and (["MACHINE_REVIEW_PACKET","HUMAN_REVIEW_PACKET","REVIEW_READY_DECISION"]|index($cell_id))!=null then
      .+{state:"REFUTED",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_REFUTED",
        next_operation:"REVIEW_OR_REPAIR_DESIGN_MISMATCH",blocked_by:["RELATION_DISPOSITIONS"]}
    elif $scenario=="authority-escalation" and $cell_id=="REVIEW_AUTHORITY_BOUND" then
      .+{state:"REFUTED",stage:"AUTHORITY",step:"BIND_REVIEW_AUTHORITY",
        reason:"AUTOMATIC_MERGE_AUTHORITY_ESCALATED",next_operation:"REMOVE_AUTOMATIC_MERGE_AUTHORITY",
        blocked_by:["review-request.json"]}
    elif $scenario=="authority-escalation" and $cell_id=="REVIEW_READY_DECISION" then
      .+{state:"REFUTED",stage:"DEPENDENCY",step:"RESOLVE_REVIEW_READY_CLAIM",reason:"DEPENDENCY_REFUTED",
        next_operation:"REMOVE_AUTOMATIC_MERGE_AUTHORITY",blocked_by:["REVIEW_AUTHORITY_BOUND"]}
    else . end
  ] as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  (if $scenario=="missing-matcher-report" then 2 else 3 end) as $release_inputs |
  (if $scenario=="missing-matcher-report" then 0 else 4 end) as $relation_count |
  (if $scenario=="claim-tuple-tamper" then 3 else 4 end) as $claim_matches |
  (if $scenario=="unreviewed-mismatch" then 0 else 1 end) as $reviewed |
  (if $scenario=="unreviewed-mismatch" then 1 else 0 end) as $unresolved |
  (if $scenario=="complete" then 2 else 0 end) as $publishable |
  (if $scenario=="missing-matcher-report" then ["matcher-normal.json"]
    elif $scenario=="claim-tuple-tamper" then ["claim-missing.json"]
    elif $scenario=="unreviewed-mismatch" then ["ios-radius-intentional-difference"]
    elif $scenario=="authority-escalation" then ["review-request.json"] else [] end) as $blocked_by |
  {
    schema:"gooo/design-evidence/review-packet/v1",scenario:$scenario,subject_sha:$subject_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "DESIGN_RELEASE_REVIEW_UNKNOWN" else "DESIGN_RELEASE_REVIEW_PACKET_GENERATED" end),
    candidate:{id:$d.candidate_id,state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "GENERATED" end)},
    claim:($resolution[0].claim+{blocked_by:$blocked_by}),
    request:{id:$request.request_id,component:$request.component,owner:$request.owner,reviewer:$request.reviewer},
    summary:{total_cells:15,closed_cells:$closed,unknown_cells:$unknown_count,refuted_cells:$refuted_count,
      release_inputs_total:3,release_inputs_observed:$release_inputs,review_requests_total:1,review_requests_observed:1,
      relation_dispositions_total:4,relation_dispositions_observed:$relation_count,
      claim_tuples_total:4,claim_tuples_observed:4,claim_tuples_matched:$claim_matches,
      claim_fields_total:24,claim_fields_observed:24,meta_decision_receipts_total:5,meta_decision_receipts_observed:5,
      meta_decision_fields_total:30,meta_decision_fields_observed:30,generated_artifacts_total:2,
      generated_artifacts_observed:2,publishable_artifacts:$publishable,review_actions:$relation_count,
      reviewed_mismatches:$reviewed,unresolved_mismatches:$unresolved,repository_writes:0,
      local_tests_run:0,cross_project_required_gates:0},
    relation_dispositions:$relations,claim_tuples:$claim_tuples,decision_receipts:$decision_receipts,
    authority:{meta_source:"examples/design-review-packet/main.gooo",resolution_source:"GOOO_ACTIVITY_VALUE_PROGRAM",
      automatic_merge_authorized:$request.authority.automatic_merge_authorized,
      repository_writes_authorized:$request.authority.repository_writes_authorized,
      live_figma_required:$request.authority.live_figma_required,central_orchestration_authorized:false},
    evidence:{graph_digest:$graph_digest,denominator_digest:$denominator_digest,request_digest:$request_digest,
      matcher_digest:$matcher_digest,matcher_conformance_digest:$matcher_conformance_digest,
      adoption_digest:$adoption_digest,claim_closed_digest:$claim_closed_digest,
      claim_missing_digest:$claim_missing_digest,claim_name_digest:$claim_name_digest,
      claim_refuted_digest:$claim_refuted_digest},
    cells:$cells,
    proofs:[$d.proofs[] as $proof|{choice:$proof.choice,total:$proof.total,
      closed:([$cells[]|select(.proof_choice==$proof.choice and .state=="CLOSED")]|length)}],
    indicator_classes:[$d.indicator_classes[] as $class|{class:$class.class,total:$class.total,
      closed:([$cells[]|select(.indicator_class==$class.class and .state=="CLOSED")]|length)}],
    indicators:[
      {id:"gooo.metric.design-review.release-inputs.v1",class:"DRIVER",value:$release_inputs,total:3,unit:"releases",activity:"ObserveReleasedMatcherEvidence"},
      {id:"gooo.metric.design-review.relation-dispositions.v1",class:"OUTCOME",value:$relation_count,total:4,unit:"relations",activity:"ProjectRelationDispositions"},
      {id:"gooo.metric.design-review.claim-tuples.v1",class:"OUTCOME",value:$claim_matches,total:4,unit:"tuples",activity:"ProjectClaimTupleLedger"},
      {id:"gooo.metric.design-review.generated-artifacts.v1",class:"OUTCOME",value:2,total:2,unit:"artifacts",activity:"GenerateHumanReviewPacket"},
      {id:"gooo.metric.design-review.publishable-artifacts.v1",class:"GUARDRAIL",value:$publishable,total:2,unit:"artifacts",activity:"ResolveReviewReadyClaim"},
      {id:"gooo.metric.design-review.repository-writes.v1",class:"GUARDRAIL",value:0,total:0,unit:"writes",activity:"ObserveReviewRuntime"}
    ]
  }
' > "$output_json"

{
  echo '# Gooo Design Release Review Packet'
  echo
  jq -r '"- Decision: `\(.decision)`", "- Claim: `\(.claim.state)` / `\(.claim.reason)`", "- Component: `\(.request.component)`", "- Owner / reviewer: `\(.request.owner)` / `\(.request.reviewer)`", "- Publishable artifacts: \(.summary.publishable_artifacts)/2"' "$output_json"
  echo
  echo '## Relation dispositions'
  if jq -e '.relation_dispositions|length>0' "$output_json" >/dev/null; then
    jq -r '.relation_dispositions[]|"- `\(.id)`: \(.state) / \(.disposition) / `\(.review_action)`"' "$output_json"
  else
    echo '- none; released matcher evidence is unavailable'
  fi
  echo
  echo '## Claim tuple ledger'
  jq -r '.claim_tuples[]|"- `\(.activity)`: \(.claim.state) / \(.claim.reason) / fields \(.fields_observed)/6"' "$output_json"
  echo
  echo '## Resolution coordinates'
  jq -r '"- stage: `\(.claim.stage // "NONE")`", "- step: `\(.claim.step // "NONE")`", "- unknown class: `\(.claim.unknown_class // "NONE")`", "- next operation: `\(.claim.next_operation)`"' "$output_json"
  echo
  echo '## Authority'
  jq -r '"- automatic merge: \(.authority.automatic_merge_authorized)", "- repository writes: \(.authority.repository_writes_authorized)", "- cross-project required gates: \(.summary.cross_project_required_gates)"' "$output_json"
} > "$output_md"
