#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 6; then
  echo "usage: match-design-code.sh GRAPH DENOMINATOR FIXTURE OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 2
fi

graph=$1
denominator=$2
fixture=$3
output=$4
subject_sha=$5
scenario=$6
tokens="$fixture/tokens.json"
code_connect="$fixture/code-connect.json"
code="$fixture/button.tsx"
css="$fixture/generated/tokens.css"
ios="$fixture/generated/tokens.ios.json"
lineage="$fixture/lineage.json"
differences="$fixture/intentional-differences.json"

for file in "$graph" "$denominator" "$tokens" "$code_connect" "$code" "$css" "$ios" "$lineage" "$differences"; do
  test -f "$file" || { echo "missing matcher input: $file" >&2; exit 2; }
done

jq -e '.schema=="gooo/design-code-match-denominator/v1" and .total==12 and (.cells|length)==12' "$denominator" >/dev/null
jq -e --slurpfile denominator "$denominator" '
  . as $graph |
  .schema_version=="gooo-graph/v1" and
  ([$graph.nodes[]|select(.kind=="Activity")]|length)==12 and
  ([$denominator[0].cells[] as $cell |
    select(([$graph.nodes[]|select(.kind=="Activity" and .name==$cell.activity)]|length)==1)
  ]|length)==12
' "$graph" >/dev/null
jq -e '.["$schema"]=="https://www.designtokens.org/schemas/2025.10/format.json"' "$tokens" >/dev/null
jq -e '.schema=="gooo/parsed-code-connect-observation/v1" and .component.name=="Button"' "$code_connect" >/dev/null
jq -e '.schema=="gooo/design-lineage/v1" and (.edges|type)=="array"' "$lineage" >/dev/null
jq -e '.schema=="gooo/intentional-design-differences/v1" and (.differences|type)=="array"' "$differences" >/dev/null

jq_bool() {
  local query=$1 file=$2
  if jq -e "$query" "$file" >/dev/null; then printf true; else printf false; fi
}

text_bool() {
  local pattern=$1 file=$2
  if grep -Fq -- "$pattern" "$file"; then printf true; else printf false; fi
}

variant_property=$(jq_bool 'any(.component.properties[];.figma_property=="Variant" and .figma_value=="Primary" and .code_property=="variant" and .code_value=="primary" and .code_type=="enum")' "$code_connect")
disabled_property=$(jq_bool 'any(.component.properties[];.figma_property=="Disabled" and .figma_value==true and .code_property=="disabled" and .code_value==true and .code_type=="boolean")' "$code_connect")
variant_edge=$(jq_bool 'any(.edges[];.relation=="IMPLEMENTED_BY" and .from.locator=="Variant=Primary" and .to.locator=="ButtonProps.variant=primary")' "$lineage")
disabled_edge=$(jq_bool 'any(.edges[];.relation=="IMPLEMENTED_BY" and .from.locator=="Disabled=true" and .to.locator=="ButtonProps.disabled=true")' "$lineage")
button_symbol=$(text_bool 'export function Button' "$code")
variant_source=$(text_bool 'variant: "primary"' "$code")
disabled_source=$(text_bool 'disabled?: boolean' "$code")

action_alias=$(jq_bool '.color.action["$value"]=="{color.blue}" and .color.blue["$type"]=="color"' "$tokens")
action_token_edge=$(jq_bool 'any(.edges[];.relation=="DERIVED_AS" and .from.locator=="/color/action" and .to.locator=="--color-action")' "$lineage")
action_use_edge=$(jq_bool 'any(.edges[];.relation=="USED_BY" and .from.locator=="--color-action" and .to.locator=="Button.background")' "$lineage")
action_css=$(text_bool '--color-action: var(--color-blue)' "$css")
action_code=$(text_bool 'var(--color-action)' "$code")

radius_token=$(jq_bool '.radius.button["$type"]=="dimension" and .radius.button["$value"]=={unit:"px",value:8}' "$tokens")
radius_ios=$(jq_bool '.radiusButton=={unit:"pt",value:6}' "$ios")
radius_edge=$(jq_bool 'any(.edges[];.relation=="INTENTIONALLY_DERIVED_AS" and .from.locator=="/radius/button" and .to.locator=="radiusButton")' "$lineage")
evaluation_date=$(jq -r .evaluation_date "$denominator")
reviewed_difference=$(jq_bool --argjson false "$differences" 2>/dev/null || true)
if jq -e --arg date "$evaluation_date" '
  any(.differences[];
    .id=="difference-ios-button-radius" and
    .source.locator=="/radius/button" and .source.value==8 and .source.unit=="px" and
    .observed.locator=="radiusButton" and .observed.value==6 and .observed.unit=="pt" and
    (.reason|length)>0 and (.scope|length)>0 and (.owner|length)>0 and (.reviewer|length)>0 and
    .expires_on>$date)
' "$differences" >/dev/null; then reviewed_difference=true; else reviewed_difference=false; fi

digest() {
  printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"
}

jq -S -n \
  --arg subject_sha "$subject_sha" \
  --arg scenario "$scenario" \
  --argjson variant_property "$variant_property" \
  --argjson disabled_property "$disabled_property" \
  --argjson variant_edge "$variant_edge" \
  --argjson disabled_edge "$disabled_edge" \
  --argjson button_symbol "$button_symbol" \
  --argjson variant_source "$variant_source" \
  --argjson disabled_source "$disabled_source" \
  --argjson action_alias "$action_alias" \
  --argjson action_token_edge "$action_token_edge" \
  --argjson action_use_edge "$action_use_edge" \
  --argjson action_css "$action_css" \
  --argjson action_code "$action_code" \
  --argjson radius_token "$radius_token" \
  --argjson radius_ios "$radius_ios" \
  --argjson radius_edge "$radius_edge" \
  --argjson reviewed_difference "$reviewed_difference" \
  --arg graph_digest "$(digest "$graph")" \
  --arg denominator_digest "$(digest "$denominator")" \
  --arg tokens_digest "$(digest "$tokens")" \
  --arg code_connect_digest "$(digest "$code_connect")" \
  --arg code_digest "$(digest "$code")" \
  --arg css_digest "$(digest "$css")" \
  --arg ios_digest "$(digest "$ios")" \
  --arg lineage_digest "$(digest "$lineage")" \
  --arg differences_digest "$(digest "$differences")" '
  def matched($id;$from;$to;$evidence):
    {id:$id,state:"MATCH",disposition:"EXPLICIT_EVIDENCE",from:$from,to:$to,evidence_count:$evidence,
      stage:null,step:null,reason:"EXPLICIT_RELATION_EVIDENCE_OBSERVED",unknown_class:null,next_operation:"NONE"};
  def unknown($id;$from;$to;$reason;$next;$evidence):
    {id:$id,state:"UNKNOWN",disposition:"EVIDENCE_MISSING",from:$from,to:$to,evidence_count:$evidence,
      stage:"RELATION",step:"RESOLVE_DESIGN_CODE_RELATION",reason:$reason,unknown_class:"DIRECT_MISSING",next_operation:$next};
  def mismatch($id;$from;$to;$disposition;$reason;$evidence):
    {id:$id,state:"MISMATCH",disposition:$disposition,from:$from,to:$to,evidence_count:$evidence,
      stage:"RELATION",step:"RESOLVE_DESIGN_CODE_RELATION",reason:$reason,unknown_class:null,
      next_operation:(if $disposition=="REVIEWED_DIFFERENCE" then "NONE" else "REPAIR_DESIGN_EVIDENCE" end)};
  [
    (if $variant_property and $variant_edge and $button_symbol and $variant_source then
      matched("figma-variant-implemented-by-code";"FIGMA:Variant=Primary";"CODE:ButtonProps.variant=primary";4)
     elif $variant_property and ($variant_edge | not) then
      unknown("figma-variant-implemented-by-code";"FIGMA:Variant=Primary";"CODE:ButtonProps.variant=primary";"NAME_ONLY_MATCH_FORBIDDEN";"PROVIDE_EXPLICIT_LINEAGE_EDGE";3)
     elif ($variant_property | not) then
      unknown("figma-variant-implemented-by-code";"FIGMA:Variant=Primary";"CODE:ButtonProps.variant=primary";"CODE_CONNECT_PROPERTY_UNAVAILABLE";"PROVIDE_CODE_CONNECT_PROPERTY";2)
     else mismatch("figma-variant-implemented-by-code";"FIGMA:Variant=Primary";"CODE:ButtonProps.variant=primary";"UNRESOLVED_CONTRADICTION";"CODE_SOURCE_BINDING_MISMATCH";2) end),
    (if $disabled_property and $disabled_edge and $button_symbol and $disabled_source then
      matched("figma-disabled-implemented-by-code";"FIGMA:Disabled=true";"CODE:ButtonProps.disabled=true";4)
     elif $disabled_property and ($disabled_edge | not) then
      unknown("figma-disabled-implemented-by-code";"FIGMA:Disabled=true";"CODE:ButtonProps.disabled=true";"NAME_ONLY_MATCH_FORBIDDEN";"PROVIDE_EXPLICIT_LINEAGE_EDGE";3)
     elif ($disabled_property | not) then
      unknown("figma-disabled-implemented-by-code";"FIGMA:Disabled=true";"CODE:ButtonProps.disabled=true";"CODE_CONNECT_PROPERTY_UNAVAILABLE";"PROVIDE_CODE_CONNECT_PROPERTY";2)
     else mismatch("figma-disabled-implemented-by-code";"FIGMA:Disabled=true";"CODE:ButtonProps.disabled=true";"UNRESOLVED_CONTRADICTION";"CODE_SOURCE_BINDING_MISMATCH";2) end),
    (if $action_alias and $action_token_edge and $action_use_edge and $action_css and $action_code then
      matched("action-token-used-by-button";"DTCG:/color/action";"CODE:Button.background";5)
     elif ($action_alias | not) then
      mismatch("action-token-used-by-button";"DTCG:/color/action";"CODE:Button.background";"UNRESOLVED_CONTRADICTION";"DTCG_ALIAS_TARGET_MISSING";4)
     elif ($action_token_edge | not) or ($action_use_edge | not) then
      unknown("action-token-used-by-button";"DTCG:/color/action";"CODE:Button.background";"EXPLICIT_LINEAGE_EDGE_UNAVAILABLE";"PROVIDE_EXPLICIT_LINEAGE_EDGE";3)
     else mismatch("action-token-used-by-button";"DTCG:/color/action";"CODE:Button.background";"UNRESOLVED_CONTRADICTION";"GENERATED_OR_CODE_USE_MISMATCH";3) end),
    (if $radius_token and $radius_ios and $radius_edge and $reviewed_difference then
      mismatch("ios-radius-intentional-difference";"DTCG:/radius/button=8px";"IOS:radiusButton=6pt";"REVIEWED_DIFFERENCE";"INTENTIONAL_DIFFERENCE_REVIEWED";4)
     else mismatch("ios-radius-intentional-difference";"DTCG:/radius/button=8px";"IOS:radiusButton=6pt";"UNRESOLVED_CONTRADICTION";"INTENTIONAL_DIFFERENCE_UNREVIEWED";2) end)
  ] | sort_by(.id) as $relations |
  ([$relations[]|select(.state=="MATCH")]|length) as $matches |
  ([$relations[]|select(.state=="UNKNOWN")]|length) as $unknowns |
  ([$relations[]|select(.state=="MISMATCH")]|length) as $mismatches |
  ([$relations[]|select(.state=="MISMATCH" and .disposition=="REVIEWED_DIFFERENCE")]|length) as $reviewed |
  ([$relations[]|select(.state=="MISMATCH" and .disposition!="REVIEWED_DIFFERENCE")]|length) as $unresolved |
  (([$relations[]|select(.state=="MISMATCH" and .disposition!="REVIEWED_DIFFERENCE")][0]) //
   ([$relations[]|select(.state=="UNKNOWN")][0])) as $first |
  {
    schema:"gooo/design-code-match-report/v1",
    scenario:$scenario,
    subject_sha:$subject_sha,
    decision:(if $unresolved>0 then "FAIL_CLOSED" elif $unknowns>0 then "DESIGN_CODE_MATCH_UNKNOWN" else "DESIGN_CODE_RELATIONS_OBSERVED" end),
    claim:(if $first==null then
      {state:"CLOSED",stage:null,step:null,reason:"DESIGN_CODE_RELATIONS_OBSERVED",unknown_class:null,next_operation:"NONE",blocked_by:[]}
      else {state:(if $unresolved>0 then "REFUTED" else "UNKNOWN" end),stage:$first.stage,step:$first.step,
        reason:$first.reason,unknown_class:$first.unknown_class,next_operation:$first.next_operation,blocked_by:[$first.id]} end),
    summary:{relations:4,match:$matches,unknown:$unknowns,mismatch:$mismatches,
      reviewed_mismatches:$reviewed,unresolved_mismatches:$unresolved,repository_writes:0},
    relations:$relations,
    authority:{meta_source:"examples/design-code-match/main.gooo",matching_mode:"EXPLICIT_EVIDENCE_ONLY",
      name_similarity_authorized:false,value_similarity_authorized:false,ai_confidence_authorized:false,
      live_figma_required:false,repository_writes:0,cross_project_required_gates:0},
    evidence:{graph_digest:$graph_digest,denominator_digest:$denominator_digest,tokens_digest:$tokens_digest,
      code_connect_digest:$code_connect_digest,code_digest:$code_digest,css_digest:$css_digest,
      ios_digest:$ios_digest,lineage_digest:$lineage_digest,differences_digest:$differences_digest}
  }
' > "$output"
