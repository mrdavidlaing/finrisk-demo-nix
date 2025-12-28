{ pkgs }:

# Shared JQ utility functions for SBOM manipulation
# Used by both merge-cyclonedx.sh and compose-cyclonedx.sh

pkgs.writeText "jq-utils.jq" ''
  # Generate a unique key for a component
  # Tries: bom-ref, purl, group/name@version, name
  def comp_key:
    (if type == "object" and . != null then
      (. ["bom-ref"] // .purl // (.group + "/" + .name + "@" + (.version // "")) // .name // "")
    else "" end);

  # Remove duplicate components based on comp_key
  # Filters out nulls and non-objects
  def uniq_components($xs):
    ($xs
    | map(select(. != null and type == "object"))
    | unique_by(comp_key));

  # Normalize dependencies by grouping and deduplicating
  # Input: array of {ref, dependsOn} objects
  # Output: array with unique refs and merged dependsOn arrays
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

  # Merge two dependency arrays
  # Combines dependencies and ensures unique refs with merged dependsOn
  def merge_deps($a; $b):
    normalize_deps(($a // []) + ($b // []))
    | group_by(.ref)
    | map({
        ref: .[0].ref,
        dependsOn: (map(.dependsOn[]) | unique)
      });
''
