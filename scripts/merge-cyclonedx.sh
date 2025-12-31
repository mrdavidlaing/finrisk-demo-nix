#!/usr/bin/env bash
set -euo pipefail

# Merge two CycloneDX SBOMs into one.
#
# Usage:
#   merge-cyclonedx.sh <sbom1.json> <sbom2.json> <out.json>

SBOM1="$1"
SBOM2="$2"
OUT_BOM="$3"

JQ="${JQ:-jq}"
JQ_UTILS="${JQ_UTILS:-}"

if [ ! -f "$SBOM1" ] || [ ! -f "$SBOM2" ]; then
  echo "missing input BOM(s)" >&2
  exit 2
fi

hash="$(cat "$SBOM1" "$SBOM2" | sha256sum | awk '{print $1}')"
uuid="${hash:0:8}-${hash:8:4}-${hash:12:4}-${hash:16:4}-${hash:20:12}"
serial="urn:uuid:$uuid"

# Load shared JQ utilities if available, otherwise define inline
if [ -n "$JQ_UTILS" ] && [ -f "$JQ_UTILS" ]; then
  JQ_FUNCS="$(cat "$JQ_UTILS")"
else
  # Fallback: inline definitions (for backward compatibility)
  JQ_FUNCS='
  def comp_key:
    (if type == "object" and . != null then
      (. ["bom-ref"] // .purl // (.group + "/" + .name + "@" + (.version // "")) // .name // "")
    else "" end);

  def uniq_components($xs):
    ($xs
    | map(select(. != null and type == "object"))
    | unique_by(comp_key));

  def normalize_deps($deps):
    ($deps // [])
    | map({
        ref: .ref,
        dependsOn: ((.dependsOn // []) | unique)
      })
    | group_by(.ref)
    | map({
        ref: .[0].ref,
        dependsOn: (map(.dependsOn[]) | unique)
      });

  def merge_deps($a; $b):
    normalize_deps(($a // []) + ($b // []))
    | group_by(.ref)
    | map({
        ref: .[0].ref,
        dependsOn: (map(.dependsOn[]) | unique)
      });
'
fi

$JQ -n   --arg specVersion "1.6"   --arg serialNumber "$serial"   --slurpfile bom1 "$SBOM1"   --slurpfile bom2 "$SBOM2"   '
'"$JQ_FUNCS"'



  # Find the main component from bom1 (Nix SBOM) - it should be in metadata.component
  def get_main_component_ref($bom):
    ($bom.metadata.component // {} | .["bom-ref"] // "");

  # Normalize a name for comparison (lowercase, remove hyphens/underscores)
  def normalize_name($name):
    (if ($name | type) == "string" then $name else "" end) | ascii_downcase | gsub("-"; "") | gsub("_"; "");

  # Check if a PURL is from a package manager
  def is_pkg_mgr($purl):
    (($purl // "") | startswith("pkg:npm")) or (($purl // "") | startswith("pkg:maven")) or (($purl // "") | startswith("pkg:nuget")) or (($purl // "") | startswith("pkg:cargo")) or (($purl // "") | startswith("pkg:golang")) or (($purl // "") | startswith("pkg:cpan")) or (($purl // "") | startswith("pkg:pypi")) or (($purl // "") | startswith("pkg:gem"));

  # Find dependency component (npm, maven, nuget, cargo, golang, cpan, pypi, or gem) that matches the main component name
  # Only returns a component if it is a CLEAR name match - otherwise returns null
  def find_dep_component($bom; $main_name):
    ($bom.components // []) as $components
    | ($bom.dependencies // []) as $deps
    | (normalize_name($main_name)) as $normalized_main
    # Filter to only package manager components first
    | ($components | map(select(.purl != null and is_pkg_mgr(.purl)))) as $pkg_mgr_components
    # Only try exact or normalized name matches - DO NOT use fallback heuristics
    # This prevents false positives where unrelated dependencies get excluded
    | (($pkg_mgr_components | map(select(try ((.name | type == "string") and (.name == $main_name)) catch false)) | if length > 0 then .[0] else null end) //
       ($pkg_mgr_components | map(select(try ((.name | type == "string") and (normalize_name(.name) == $normalized_main)) catch false)) | if length > 0 then .[0] else null end)) // null
    | if . == null or type != "object" then null else . end;

  # Get dependencies for a specific component ref
  def get_deps_for_ref($deps; $ref):
    ($deps // []) | map(select(.ref == $ref)) | .[0] // null | if . then .dependsOn // [] else [] end;

  ($bom1[0]) as $b1
  | ($bom2[0]) as $b2
  
  # Get main component ref from Nix SBOM
  | (get_main_component_ref($b1)) as $main_ref
  
  # Find matching dependency component in b2 (to exclude it)
  | ($b1.metadata.component.name // "") as $main_name
  | (find_dep_component($b2; $main_name)) as $dep_component
  | (if $dep_component and ($dep_component | type) == "object" then $dep_component["bom-ref"] // "" else "" end) as $dep_component_ref
  
  # Filter b2 components (exclude dep_component)
  | (($b2.components // []) | map(select(.["bom-ref"] != $dep_component_ref))) as $b2_components_filtered
  
  # Filter b2 dependencies (exclude entries for dep_component)
  | (($b2.dependencies // []) | map(select(.ref != $dep_component_ref))) as $b2_deps_filtered
  
  # Identify roots in b2 (refs in components but not in any dependsOn)
  # 1. Get all refs in filtered components
  | ($b2_components_filtered | map(.["bom-ref"])) as $all_refs
  # 2. Get all target refs in filtered dependencies
  | ($b2_deps_filtered | map(.dependsOn[]) | unique) as $child_refs
  # 3. Roots = all_refs - child_refs
  | ($all_refs - $child_refs) as $roots
  
  # Merge components
  | (uniq_components(($b1.components // []) + $b2_components_filtered)) as $all_components
  
  # Merge dependencies
  | (merge_deps($b1.dependencies; $b2_deps_filtered)) as $base_deps
  
  # Add roots to main_ref
  | (if $main_ref != "" and ($roots | length) > 0 then
      ($base_deps | map(
        if .ref == $main_ref then
          . + {dependsOn: ((.dependsOn // []) + $roots | unique)}
        else .
        end
      ))
    else
      $base_deps
    end) as $final_deps
  
  | {
    bomFormat: ($b1.bomFormat // $b2.bomFormat // "CycloneDX"),
    specVersion: $specVersion,
    serialNumber: $serialNumber,
    version: 1,
    metadata: $b1.metadata,
    components: $all_components,
    dependencies: $final_deps
  }
' > "$OUT_BOM"

echo "[merge] merged $SBOM1 + $SBOM2 -> $OUT_BOM"

