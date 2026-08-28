#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 8; then
  echo "usage: evaluate-design-code-match.sh DENOMINATOR NORMAL UNKNOWN NAME_ONLY REFUTED RUNTIME OUTPUT SUBJECT_SHA" >&2
  exit 2
fi

denominator=$1
normal=$2
unknown=$3
name_only=$4
refuted=$5
runtime=$6
output=$7
subject_sha=$8

for file in "$denominator" "$normal" "$unknown" "$name_only" "$refuted" "$runtime"; do
  test -f "$file" || { echo "missing conformance input: $file" >&2; exit 2; }
done

jq -e '.schema=="gooo/design-code-match-denominator/v1" and .total==12 and (.cells|length)==12 and ([.proofs[].total]|add)==12 and ([.indicator_classes[].total]|add)==12' "$denominator" >/dev/null
jq -e '
  .schema=="gooo/design-code-match-report/v1" and .decision=="DESIGN_CODE_RELATIONS_OBSERVED" and
  .claim.state=="CLOSED" and
  .summary=={match:3,mismatch:1,relations:4,repository_writes:0,reviewed_mismatches:1,unknown:0,unresolved_mismatches:0} and
  ([.relations[]|select(.state=="MATCH")]|length)==3 and
  ([.relations[]|select(.state=="MISMATCH" and .disposition=="REVIEWED_DIFFERENCE")]|length)==1 and
  .authority.matching_mode=="EXPLICIT_EVIDENCE_ONLY" and .authority.live_figma_required==false and
  .authority.repository_writes==0 and .authority.cross_project_required_gates==0
' "$normal" >/dev/null
jq -e '
  .decision=="DESIGN_CODE_MATCH_UNKNOWN" and .claim.state=="UNKNOWN" and
  .claim.reason=="CODE_CONNECT_PROPERTY_UNAVAILABLE" and .claim.unknown_class=="DIRECT_MISSING" and
  .summary.match==2 and .summary.unknown==1 and .summary.mismatch==1
' "$unknown" >/dev/null
jq -e '
  .decision=="DESIGN_CODE_MATCH_UNKNOWN" and .claim.state=="UNKNOWN" and
  .claim.reason=="NAME_ONLY_MATCH_FORBIDDEN" and .claim.unknown_class=="DIRECT_MISSING" and
  .summary.match==2 and .summary.unknown==1 and .summary.mismatch==1 and
  .authority.name_similarity_authorized==false
' "$name_only" >/dev/null
jq -e '
  .decision=="FAIL_CLOSED" and .claim.state=="REFUTED" and
  .claim.reason=="DTCG_ALIAS_TARGET_MISSING" and
  .summary.match==2 and .summary.unknown==0 and .summary.mismatch==2 and
  .summary.reviewed_mismatches==1 and .summary.unresolved_mismatches==1
' "$refuted" >/dev/null
jq -e '
  .schema=="gooo/design-code-match-runtime/v1" and .peak_rss_kib>0 and .wall_ms>=0 and
  .repository_writes==0 and .local_tests_run==0 and .cross_project_required_gates==0 and
  .deterministic_replay==true
' "$runtime" >/dev/null

digest() {
  printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"
}

jq -S -n \
  --slurpfile denominator "$denominator" \
  --slurpfile normal "$normal" \
  --slurpfile runtime "$runtime" \
  --arg subject_sha "$subject_sha" \
  --arg denominator_digest "$(digest "$denominator")" \
  --arg normal_digest "$(digest "$normal")" \
  --arg unknown_digest "$(digest "$unknown")" \
  --arg name_only_digest "$(digest "$name_only")" \
  --arg refuted_digest "$(digest "$refuted")" \
  --arg runtime_digest "$(digest "$runtime")" '
  $denominator[0] as $d |
  $normal[0] as $normal |
  $runtime[0] as $runtime |
  [$d.cells[]|{id,activity,proof_choice,indicator_class,state:"CLOSED",reason:.closed_reason,
    unknown_class:null,next_operation:"NONE"}] as $cells |
  {
    schema:"gooo/design-code-match-conformance/v1",
    subject_sha:$subject_sha,
    decision:"DESIGN_CODE_MATCHER_CONFORMANT",
    candidate:{id:$d.candidate_id,state:"IMPLEMENTED",implementation_status:"INDEPENDENT_VERTICAL_SLICE_OBSERVED"},
    claim:{state:"CLOSED",stage:null,step:null,reason:"DESIGN_CODE_MATCHER_VERTICAL_SLICE_CLOSED",
      unknown_class:null,next_operation:"PUBLISH_IMMUTABLE_DESIGN_PRODUCT_RELEASE",blocked_by:[]},
    summary:{total_cells:12,closed_cells:12,unknown_cells:0,refuted_cells:0,
      input_classes:7,relation_outputs:4,match:$normal.summary.match,unknown_relations:$normal.summary.unknown,
      mismatch:$normal.summary.mismatch,reviewed_mismatches:$normal.summary.reviewed_mismatches,
      adversarial_scenarios:3,repository_writes:$runtime.repository_writes,
      local_tests_run:$runtime.local_tests_run,cross_project_required_gates:$runtime.cross_project_required_gates},
    cells:$cells,
    proofs:([$d.proofs[] as $proof|{choice:$proof.choice,
      closed:([$cells[]|select(.proof_choice==$proof.choice)]|length),total:$proof.total}]),
    indicator_classes:([$d.indicator_classes[] as $class|{class:$class.class,
      closed:([$cells[]|select(.indicator_class==$class.class)]|length),total:$class.total}]),
    indicators:[
      {id:"gooo.metric.design-code.relations.v1",class:"OUTCOME",value:4,total:4,unit:"relations",state:"SATISFIED",activity:"EvaluateMatchRelations"},
      {id:"gooo.metric.design-code.matches.v1",class:"OUTCOME",value:$normal.summary.match,total:3,unit:"relations",state:"SATISFIED",activity:"EvaluateMatchRelations"},
      {id:"gooo.metric.design-code.reviewed-mismatches.v1",class:"OUTCOME",value:$normal.summary.reviewed_mismatches,total:1,unit:"relations",state:"SATISFIED",activity:"ReviewDesignDifference"},
      {id:"gooo.metric.design-code.adversarial-scenarios.v1",class:"GUARDRAIL",value:3,total:3,unit:"scenarios",state:"SATISFIED",activity:"PreserveMissingEvidenceUnknown"},
      {id:"gooo.metric.design-code.repository-writes.v1",class:"GUARDRAIL",value:$runtime.repository_writes,target:0,unit:"writes",state:"SATISFIED",activity:"ObserveMatcherRuntime"},
      {id:"gooo.metric.design-code.peak-rss.v1",class:"GUARDRAIL",value:$runtime.peak_rss_kib,unit:"KiB",state:"OBSERVED",activity:"ObserveMatcherRuntime"},
      {id:"gooo.metric.design-code.wall-time.v1",class:"GUARDRAIL",value:$runtime.wall_ms,unit:"ms",state:"OBSERVED",activity:"ObserveMatcherRuntime"}
    ],
    authority:{meta_source:"examples/design-code-match/main.gooo",matching_mode:"EXPLICIT_EVIDENCE_ONLY",
      live_figma_required:false,repository_writes:$runtime.repository_writes,
      local_tests_run:$runtime.local_tests_run,cross_project_required_gates:$runtime.cross_project_required_gates},
    evidence:{denominator_digest:$denominator_digest,normal_digest:$normal_digest,
      unknown_digest:$unknown_digest,name_only_digest:$name_only_digest,
      refuted_digest:$refuted_digest,runtime_digest:$runtime_digest}
  }
' > "$output"
