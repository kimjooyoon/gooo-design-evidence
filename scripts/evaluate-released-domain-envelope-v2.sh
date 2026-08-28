#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 5; then
  echo "usage: evaluate-released-domain-envelope-v2.sh ROOT CORE_RECEIPTS FACTS OUTPUT SUBJECT_SHA" >&2
  exit 64
fi

root=$(realpath "$1")
core_receipts=$2
facts=$3
output=$4
subject_sha=$5
denominator="$root/contracts/released-domain-envelope-denominator-v2.json"
for file in "$denominator" "$core_receipts" "$facts"; do
  test -f "$file" || { echo "missing input: $file" >&2; exit 65; }
done

jq -S -n --slurpfile denominator "$denominator" --slurpfile core "$core_receipts" --slurpfile facts "$facts" --arg subject_sha "$subject_sha" '
  ($denominator[0]) as $d |
  ($facts[0]) as $f |
  ($core[0]|map({key:.selector.name,value:.})|from_entries) as $receipt_by |
  def strip: del(.closed_reason,.unknown_reason,.refuted_reason);
  def normalized_core($cell):
    ($receipt_by[$cell.activity]//null) as $r |
    if $r==null then
      {state:"UNKNOWN",stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",reason:"CORE_ACTIVITY_RESOLUTION_RECEIPT_UNAVAILABLE",unknown_class:"DIRECT_MISSING",next_operation:"PROVIDE_CORE_ACTIVITY_RESOLUTION_RECEIPT",blocked_by:[]}
    elif $r.decision=="CLOSED" and $r.occurrences==1 and $r.claim.state=="CLOSED" and $r.claim.reason=="ACTIVITY_UNIQUELY_RESOLVED" then
      {state:"CLOSED",stage:null,step:null,reason:"ACTIVITY_UNIQUELY_RESOLVED",unknown_class:null,next_operation:"NONE",blocked_by:[]}
    elif $r.decision=="UNKNOWN" and $r.claim.state=="UNKNOWN" and (($r.occurrences|type)=="number") and $r.occurrences==0 and $r.claim.reason=="ACTIVITY_NOT_FOUND" then
      {state:"UNKNOWN",stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",reason:"ACTIVITY_NOT_FOUND",unknown_class:"DIRECT_MISSING",next_operation:"PROVIDE_UNIQUE_ACTIVITY_BINDING",blocked_by:[]}
    elif $r.decision=="REFUTED" and $r.claim.state=="REFUTED" and (($r.occurrences|type)=="number") and $r.occurrences>1 and $r.claim.reason=="AMBIGUOUS_ACTIVITY_BINDING" then
      {state:"REFUTED",stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",reason:"AMBIGUOUS_ACTIVITY_BINDING",unknown_class:null,next_operation:"RESTORE_UNIQUE_ACTIVITY_BINDING",blocked_by:[]}
    else
      {state:"REFUTED",stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",reason:"UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION",unknown_class:null,next_operation:"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPT",blocked_by:[]}
    end;
  def fact($id):
    if $id=="CORE_RELEASE" then $f.observations.core_release
    elif $id=="SPEC_RELEASE" then $f.observations.spec_release
    elif $id=="DESIGN_RELEASE" then $f.observations.design_release
    elif $id=="META_ACTIVITY_AUTHORITY" then $f.observations.meta_activity_authority
    elif $id=="CLAIM_DISPOSITION_SOURCE" then ($f.source.claim_disposition_tuples.observed==$f.source.claim_disposition_tuples.total and $f.source.relation_dispositions.observed==$f.source.relation_dispositions.total)
    elif $id=="PRODUCT_PROJECTION" then ($f.projection.product_owned_projection.observed==$f.projection.product_owned_projection.total and $f.projection.relations.observed==$f.projection.relations.total and $f.projection.evidence.observed==$f.projection.evidence.total and $f.projection.resolutions.observed==$f.projection.resolutions.total)
    elif $id=="EIGHT_FILE_ENVELOPE" then $f.projection.envelope_files.observed==$f.projection.envelope_files.total
    elif $id=="READ_ONLY_CONFORMANCE" then ($f.projection.conformer_checks.observed==$f.projection.conformer_checks.total and $f.projection.conformer_decision=="CONFORMANT")
    elif $id=="UNKNOWN_CAUSALITY" then ($f.unknown_cases.valid.observed==$f.unknown_cases.valid.total and $f.unknown_cases.coordinate_fields_observed==$f.unknown_cases.coordinate_fields_total and $f.unknown_cases.classes.direct_missing.observed==$f.unknown_cases.classes.direct_missing.total and $f.unknown_cases.classes.dependency_blocked.observed==$f.unknown_cases.classes.dependency_blocked.total)
    elif $id=="DETERMINISTIC_REPLAY" then $f.projection.deterministic_replay.observed==$f.projection.deterministic_replay.total
    elif $id=="REFUTED_COUNTEREXAMPLES" then ($f.refuted_cases.observed==$f.refuted_cases.total and $f.refuted_cases.all_fail_closed==true)
    elif $id=="AUTHORITY_BOUNDARY" then ($f.runtime.repository.writes==0 and $f.runtime.local_test_executions==0 and $f.runtime.cross_project_required_gates==0 and $f.runtime.product_generation_authorized==false)
    else null end;
  (reduce $d.cells[] as $cell ([ ];
    . as $prior | (normalized_core($cell)) as $cr |
    (fact($cell.id)) as $fact |
    ([$prior[] as $p|select(($cell.depends_on|index($p.id))!=null)|select($p.state=="REFUTED")|$p]) as $refuted_dependencies |
    ([$prior[] as $p|select(($cell.depends_on|index($p.id))!=null)|select($p.state=="UNKNOWN")|$p]) as $unknown_dependencies |
    (if $cr.state=="REFUTED" then
       ($cell|strip)+{state:"REFUTED",resolution:"EXACT",stage:$cr.stage,step:$cr.step,reason:$cr.reason,unknown_class:null,next_operation:$cr.next_operation,blocked_by:[]}
     elif $cr.state=="UNKNOWN" then
       ($cell|strip)+{state:"UNKNOWN",resolution:"PREREQUISITE_CLASS",stage:$cr.stage,step:$cr.step,reason:$cr.reason,unknown_class:$cr.unknown_class,next_operation:$cr.next_operation,blocked_by:[]}
     elif $fact==true then
       ($cell|strip)+{state:"CLOSED",resolution:"EXACT",stage:null,step:null,reason:$cell.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]}
     elif $fact==null then
       ($cell|strip)+{state:"UNKNOWN",resolution:"PREREQUISITE_CLASS",stage:$cell.stage,step:$cell.step,reason:$cell.unknown_reason,unknown_class:"DIRECT_MISSING",next_operation:$cell.next_operation,blocked_by:[]}
     else
       ($cell|strip)+{state:"REFUTED",resolution:"EXACT",stage:$cell.stage,step:$cell.step,reason:$cell.refuted_reason,unknown_class:null,next_operation:$cell.next_operation,blocked_by:[]}
     end) as $candidate |
    if $candidate.state=="REFUTED" then .+[$candidate]
    elif ($refuted_dependencies|length)>0 then .+[($candidate+{state:"REFUTED",resolution:"EXACT",stage:$cell.stage,step:$cell.step,reason:"DEPENDENCY_REFUTED",unknown_class:null,next_operation:"RESOLVE_REFUTED_PREDECESSORS",blocked_by:[$refuted_dependencies[].id]})]
    elif $candidate.state=="UNKNOWN" then .+[$candidate]
    elif ($unknown_dependencies|length)>0 then .+[($candidate+{state:"UNKNOWN",resolution:"PREREQUISITE_CLASS",stage:$cell.stage,step:$cell.step,reason:"DEPENDENCY_UNKNOWN",unknown_class:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_UNKNOWN_PREDECESSORS",blocked_by:[$unknown_dependencies[].id]})]
    else .+[$candidate] end)) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted |
  ([$cells[]|select(.state!="CLOSED")][0]//null) as $first |
  {schema:"gooo/design-evidence/released-domain-envelope-adoption-report/v2",subject_sha:$subject_sha,
   decision:(if $refuted>0 then "FAIL_CLOSED" elif $unknown>0 then "INCOMPLETE" else "ADOPTION_CANDIDATE_CONFORMANT" end),
   claim:(if $first==null then {state:"CLOSED",stage:null,step:null,reason:"RELEASED_DOMAIN_ENVELOPE_ADOPTION_CANDIDATE_CONFORMANT",unknown_class:null,next_operation:"NONE",blocked_by:[]} else {state:$first.state,stage:$first.stage,step:$first.step,reason:$first.reason,unknown_class:$first.unknown_class,next_operation:$first.next_operation,blocked_by:$first.blocked_by} end),
   summary:{total:$d.target_cells,closed:$closed,unknown:$unknown,refuted:$refuted,product_owned_projection:$f.projection.product_owned_projection,envelope_files:$f.projection.envelope_files,relations:$f.projection.relations,evidence:$f.projection.evidence,resolutions:$f.projection.resolutions,conformer_checks:$f.projection.conformer_checks,deterministic_replay:$f.projection.deterministic_replay},
   artifact_counts:{inputs:$f.artifacts.inputs,outputs:$f.artifacts.outputs,claim_disposition_tuples:$f.source.claim_disposition_tuples},
   state_examples:{normal:$f.normal_cases,unknown:$f.unknown_cases,refuted:$f.refuted_cases},
   adoption:$f.adoption,
   improvement:$f.improvement,
   authority:{cross_project_required_gates:$f.runtime.cross_project_required_gates,root_readme_readiness:"EXCLUDED",automatic_merge_authorized:false,repository_writes:$f.runtime.repository.writes,product_generation_authorized:$f.runtime.product_generation_authorized},
   source:{claim_tuples:$f.source.claim_disposition_tuples,known_contradiction:$f.source.known_contradiction,unknown_coordinate_fields:{observed:$f.unknown_cases.coordinate_fields_observed,total:$f.unknown_cases.coordinate_fields_total},resolution_precedence:["REFUTED","UNKNOWN","CLOSED"]},
   proofs:( ["FOUNDATION","COHERENCE","REGRESSION"] | map(. as $choice|{choice:$choice,closed:([$cells[]|select(.proof_choice==$choice and .state=="CLOSED")]|length),total:([$cells[]|select(.proof_choice==$choice)]|length)}) ),
   indicator_classes:( ["DRIVER","OUTCOME","GUARDRAIL"] | map(. as $class|{class:$class,closed:([$cells[]|select(.indicator_class==$class and .state=="CLOSED")]|length),total:([$cells[]|select(.indicator_class==$class)]|length)}) ),
   cells:$cells,
   runtime:$f.runtime}' > "$output"
