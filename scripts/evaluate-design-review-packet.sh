#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 10; then
  echo "usage: evaluate-design-review-packet.sh DENOMINATOR NORMAL_JSON NORMAL_MD UNKNOWN TUPLE_REFUTED MISMATCH_REFUTED AUTHORITY_REFUTED RUNTIME OUTPUT SUBJECT_SHA" >&2
  exit 2
fi

denominator=$1
normal=$2
normal_md=$3
unknown=$4
tuple_refuted=$5
mismatch_refuted=$6
authority_refuted=$7
runtime=$8
output=$9
subject_sha=${10}

for file in "$denominator" "$normal" "$normal_md" "$unknown" "$tuple_refuted" "$mismatch_refuted" "$authority_refuted" "$runtime"; do
  test -f "$file" || { echo "missing review conformance input: $file" >&2; exit 2; }
done

jq -e '
  .schema=="gooo/design-evidence/review-packet-denominator/v1" and .total==15 and
  (.cells|length)==15 and ([.proofs[].total]|add)==15 and ([.indicator_classes[].total]|add)==15
' "$denominator" >/dev/null

jq -e '
  .schema=="gooo/design-evidence/review-packet/v1" and .scenario=="complete" and
  .decision=="DESIGN_RELEASE_REVIEW_PACKET_GENERATED" and .candidate.state=="GENERATED" and
  .claim.state=="CLOSED" and .claim.reason=="DESIGN_RELEASE_REVIEW_PACKET_GENERATED" and
  .summary.total_cells==15 and .summary.closed_cells==15 and .summary.unknown_cells==0 and .summary.refuted_cells==0 and
  .summary.release_inputs_observed==3 and .summary.release_inputs_total==3 and
  .summary.review_requests_observed==1 and .summary.review_requests_total==1 and
  .summary.relation_dispositions_observed==4 and .summary.relation_dispositions_total==4 and
  .summary.claim_tuples_observed==4 and .summary.claim_tuples_matched==4 and .summary.claim_fields_observed==24 and
  .summary.meta_decision_receipts_observed==5 and .summary.meta_decision_fields_observed==30 and
  .summary.generated_artifacts_observed==2 and .summary.publishable_artifacts==2 and .summary.review_actions==4 and
  .summary.reviewed_mismatches==1 and .summary.unresolved_mismatches==0 and
  .summary.repository_writes==0 and .summary.local_tests_run==0 and .summary.cross_project_required_gates==0 and
  ([.relation_dispositions[]|select(.review_action=="PRESERVE_EXPLICIT_BINDING")]|length)==3 and
  ([.relation_dispositions[]|select(.review_action=="PRESERVE_REVIEWED_EXCEPTION")]|length)==1 and
  (.claim_tuples|length)==4 and (.decision_receipts|length)==5 and
  ([.proofs[]|select(.closed==5 and .total==5)]|length)==3 and
  ([.indicator_classes[]|select(.closed==5 and .total==5)]|length)==3 and
  .authority.resolution_source=="GOOO_ACTIVITY_VALUE_PROGRAM" and
  .authority.automatic_merge_authorized==false and .authority.repository_writes_authorized==false
' "$normal" >/dev/null

jq -e '
  .scenario=="missing-matcher-report" and .decision=="DESIGN_RELEASE_REVIEW_UNKNOWN" and
  .candidate.state=="UNKNOWN" and .claim.state=="UNKNOWN" and .claim.stage=="RELEASE_EVIDENCE" and
  .claim.step=="OBSERVE_RELEASED_MATCHER_EVIDENCE" and .claim.reason=="MATCHER_RELEASE_REPORT_UNAVAILABLE" and
  .claim.unknown_class=="DIRECT_MISSING" and .claim.next_operation=="RESTORE_MATCHER_RELEASE_REPORT" and
  .summary.closed_cells==10 and .summary.unknown_cells==5 and .summary.refuted_cells==0 and
  .summary.release_inputs_observed==2 and .summary.relation_dispositions_observed==0 and
  .summary.publishable_artifacts==0 and
  ([.cells[]|select(.state=="UNKNOWN" and .unknown_class=="DEPENDENCY_BLOCKED")]|length)==4
' "$unknown" >/dev/null

jq -e '
  .scenario=="claim-tuple-tamper" and .decision=="FAIL_CLOSED" and .candidate.state=="REFUTED" and
  .claim.state=="REFUTED" and .claim.stage=="CLAIM_COMPARISON" and
  .claim.reason=="RELEASED_CLAIM_TUPLE_MISMATCH" and .claim.next_operation=="RESTORE_RELEASED_CLAIM_TUPLES" and
  .summary.closed_cells==11 and .summary.unknown_cells==0 and .summary.refuted_cells==4 and
  .summary.claim_tuples_observed==4 and .summary.claim_tuples_matched==3 and .summary.publishable_artifacts==0
' "$tuple_refuted" >/dev/null

jq -e '
  .scenario=="unreviewed-mismatch" and .decision=="FAIL_CLOSED" and .candidate.state=="REFUTED" and
  .claim.state=="REFUTED" and .claim.stage=="RELATION_POLICY" and .claim.reason=="UNREVIEWED_DESIGN_MISMATCH" and
  .claim.next_operation=="REVIEW_OR_REPAIR_DESIGN_MISMATCH" and
  .summary.closed_cells==11 and .summary.refuted_cells==4 and .summary.reviewed_mismatches==0 and
  .summary.unresolved_mismatches==1 and .summary.publishable_artifacts==0 and
  ([.relation_dispositions[]|select(.review_action=="REVIEW_OR_REPAIR_DESIGN_MISMATCH")]|length)==1
' "$mismatch_refuted" >/dev/null

jq -e '
  .scenario=="authority-escalation" and .decision=="FAIL_CLOSED" and .candidate.state=="REFUTED" and
  .claim.state=="REFUTED" and .claim.stage=="AUTHORITY" and .claim.reason=="AUTOMATIC_MERGE_AUTHORITY_ESCALATED" and
  .claim.next_operation=="REMOVE_AUTOMATIC_MERGE_AUTHORITY" and
  .summary.closed_cells==13 and .summary.refuted_cells==2 and .summary.publishable_artifacts==0 and
  .authority.automatic_merge_authorized==true
' "$authority_refuted" >/dev/null

jq -e '
  .schema=="gooo/design-evidence/review-packet-runtime/v1" and .go_version=="go1.27.0" and
  .go_fix_module_roots==0 and .peak_rss_kib>0 and .wall_ms>=0 and
  .inventory.repository_files>0 and .inventory.descendant_directories>0 and
  .inventory.root_readme_excluded==true and
  (.inventory.per_file|length)==(.inventory.go.files+.inventory.gooo.files) and
  .decision_receipts_equal==5 and .replay_comparisons_equal==2 and
  .repository_writes==0 and .local_tests_run==0 and .cross_project_required_gates==0
' "$runtime" >/dev/null

grep -Fq '# Gooo Design Release Review Packet' "$normal_md"
grep -Fq -- '- Decision: `DESIGN_RELEASE_REVIEW_PACKET_GENERATED`' "$normal_md"
grep -Fq -- '- Publishable artifacts: 2/2' "$normal_md"
grep -Fq '## Relation dispositions' "$normal_md"
grep -Fq '## Claim tuple ledger' "$normal_md"
grep -Fq '## Resolution coordinates' "$normal_md"
grep -Fq '## Authority' "$normal_md"

digest() {
  printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"
}

jq -S -n \
  --slurpfile denominator "$denominator" --slurpfile normal "$normal" --slurpfile runtime "$runtime" \
  --arg subject_sha "$subject_sha" --arg denominator_digest "$(digest "$denominator")" \
  --arg normal_digest "$(digest "$normal")" --arg markdown_digest "$(digest "$normal_md")" \
  --arg unknown_digest "$(digest "$unknown")" --arg tuple_refuted_digest "$(digest "$tuple_refuted")" \
  --arg mismatch_refuted_digest "$(digest "$mismatch_refuted")" --arg authority_refuted_digest "$(digest "$authority_refuted")" \
  --arg runtime_digest "$(digest "$runtime")" '
  $denominator[0] as $d | $normal[0] as $normal | $runtime[0] as $runtime |
  [$d.cells[]|{id,activity,proof_choice,indicator_class,state:"CLOSED",stage:null,step:null,
    reason:.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]}] as $cells |
  {
    schema:"gooo/design-evidence/review-packet-conformance/v1",subject_sha:$subject_sha,
    decision:"DESIGN_RELEASE_REVIEW_PACKET_CONFORMANT",
    candidate:{id:$d.candidate_id,state:"IMPLEMENTED",implementation_status:"INDEPENDENT_USER_PATH_OBSERVED"},
    claim:{state:"CLOSED",stage:null,step:null,reason:"DESIGN_RELEASE_REVIEW_PACKET_CONFORMANT",
      unknown_class:null,next_operation:"PUBLISH_IMMUTABLE_DESIGN_REVIEW_PACKET_RELEASE",blocked_by:[]},
    summary:{total_cells:15,closed_cells:15,unknown_cells:0,refuted_cells:0,
      release_inputs_total:3,release_inputs_observed:3,review_requests_total:1,review_requests_observed:1,
      relation_dispositions_total:4,relation_dispositions_observed:4,claim_tuples_total:4,claim_tuples_observed:4,
      claim_fields_total:24,claim_fields_observed:24,meta_decision_receipts_total:5,meta_decision_receipts_observed:5,
      meta_decision_fields_total:30,meta_decision_fields_observed:30,generated_artifacts_total:2,
      generated_artifacts_observed:2,counterexamples_total:4,counterexamples_observed:4,
      replay_comparisons_total:2,replay_comparisons_equal:$runtime.replay_comparisons_equal,
      repository_writes:$runtime.repository_writes,local_tests_run:$runtime.local_tests_run,
      cross_project_required_gates:$runtime.cross_project_required_gates},
    inventory:$runtime.inventory,performance:{peak_rss_kib:$runtime.peak_rss_kib,wall_ms:$runtime.wall_ms},
    cells:$cells,
    proofs:[$d.proofs[]|{choice,total,closed:.total}],
    indicator_classes:[$d.indicator_classes[]|{class,total,closed:.total}],
    indicators:[
      {id:"gooo.metric.design-review.release-inputs.v1",class:"DRIVER",value:3,total:3,unit:"releases",activity:"ObserveReleasedMatcherEvidence"},
      {id:"gooo.metric.design-review.review-requests.v1",class:"DRIVER",value:1,total:1,unit:"requests",activity:"ObserveReviewRequest"},
      {id:"gooo.metric.design-review.relation-dispositions.v1",class:"OUTCOME",value:4,total:4,unit:"relations",activity:"ProjectRelationDispositions"},
      {id:"gooo.metric.design-review.claim-tuples.v1",class:"OUTCOME",value:4,total:4,unit:"tuples",activity:"ProjectClaimTupleLedger"},
      {id:"gooo.metric.design-review.claim-fields.v1",class:"OUTCOME",value:24,total:24,unit:"fields",activity:"ProjectClaimTupleLedger"},
      {id:"gooo.metric.design-review.meta-decision-receipts.v1",class:"OUTCOME",value:5,total:5,unit:"receipts",activity:"ResolveReviewReadyClaim"},
      {id:"gooo.metric.design-review.generated-artifacts.v1",class:"OUTCOME",value:2,total:2,unit:"artifacts",activity:"GenerateHumanReviewPacket"},
      {id:"gooo.metric.design-review.counterexamples.v1",class:"GUARDRAIL",value:4,total:4,unit:"scenarios",activity:"PreserveMissingMatcherUnknown"},
      {id:"gooo.metric.design-review.replay.v1",class:"GUARDRAIL",value:$runtime.replay_comparisons_equal,total:2,unit:"comparisons",activity:"ObserveReviewRuntime"},
      {id:"gooo.metric.design-review.repository-writes.v1",class:"GUARDRAIL",value:$runtime.repository_writes,total:0,unit:"writes",activity:"ObserveReviewRuntime"},
      {id:"gooo.metric.design-review.peak-rss.v1",class:"GUARDRAIL",value:$runtime.peak_rss_kib,unit:"KiB",activity:"ObserveReviewRuntime"},
      {id:"gooo.metric.design-review.wall-time.v1",class:"GUARDRAIL",value:$runtime.wall_ms,unit:"ms",activity:"ObserveReviewRuntime"}
    ],
    authority:{meta_source:"examples/design-review-packet/main.gooo",resolution_source:"GOOO_ACTIVITY_VALUE_PROGRAM",
      automatic_merge_authorized:false,repository_writes_authorized:false,live_figma_required:false,
      central_orchestration_authorized:false},
    evidence:{denominator_digest:$denominator_digest,normal_digest:$normal_digest,markdown_digest:$markdown_digest,
      unknown_digest:$unknown_digest,tuple_refuted_digest:$tuple_refuted_digest,
      mismatch_refuted_digest:$mismatch_refuted_digest,authority_refuted_digest:$authority_refuted_digest,
      runtime_digest:$runtime_digest}
  }
' > "$output"
