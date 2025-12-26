#!/usr/bin/env bash
set -euo pipefail

# Compose a container CycloneDX SBOM from base/runtime/app SBOMs.
#
# Usage:
#   compose-cyclonedx.sh <base.json> <runtime.json> <app.json> <out.json> <service> <imageName> <imageVersion>

BASE_BOM="$1"
RUNTIME_BOM="$2"
APP_BOM="$3"
OUT_BOM="$4"
SERVICE="$5"
IMAGE_NAME="$6"
IMAGE_VERSION="$7"

JQ="${JQ:-jq}"

if [ ! -f "$BASE_BOM" ] || [ ! -f "$RUNTIME_BOM" ] || [ ! -f "$APP_BOM" ]; then
  echo "missing input BOM(s)" >&2
  exit 2
fi

hash="$(cat "$BASE_BOM" "$RUNTIME_BOM" "$APP_BOM" | sha256sum | awk '{print $1}')"
uuid="${hash:0:8}-${hash:8:4}-${hash:12:4}-${hash:16:4}-${hash:20:12}"
serial="urn:uuid:$uuid"

$JQ -n   --arg specVersion "1.5"   --arg serialNumber "$serial"   --arg service "$SERVICE"   --arg imageName "$IMAGE_NAME"   --arg imageVersion "$IMAGE_VERSION"   --arg baseFile "$(basename "$BASE_BOM")"   --arg runtimeFile "$(basename "$RUNTIME_BOM")"   --arg appFile "$(basename "$APP_BOM")"   --slurpfile base "$BASE_BOM"   --slurpfile runtime "$RUNTIME_BOM"   --slurpfile app "$APP_BOM"   '
  def bom_component($b):
    ($b[0].metadata.component // { "type":"application", "name":"unknown", "version":"0", "bom-ref":"unknown" })
    | . as $c
    | if ($c["bom-ref"]? // "") == "" then ($c + {"bom-ref": ($c.purl // $c.name // "unknown")}) else $c end;

  def comp_key:
    (. ["bom-ref"] // .purl // (.group + "/" + .name + "@" + (.version // "")) // .name);

  def uniq_components($xs):
    ($xs | map(select(. != null)) | unique_by(comp_key));

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

  ($base[0]) as $baseBom
  | ($runtime[0]) as $runtimeBom
  | ($app[0]) as $appBom
  | bom_component($base) as $baseC
  | bom_component($runtime) as $runtimeC
  | bom_component($app) as $appC
  | ("container:" + $service) as $containerRef
  | {
      bomFormat: "CycloneDX",
      specVersion: $specVersion,
      serialNumber: $serialNumber,
      version: 1,
      metadata: {
        component: {
          "bom-ref": $containerRef,
          type: "container",
          name: $imageName,
          version: $imageVersion,
          externalReferences: [
            { type: "bom", url: $baseFile },
            { type: "bom", url: $runtimeFile },
            { type: "bom", url: $appFile }
          ]
        }
      },
      components: uniq_components(
        [ $baseC, $runtimeC, $appC ]
        + ($baseBom.components // [])
        + ($runtimeBom.components // [])
        + ($appBom.components // [])
      ),
      dependencies: (
        merge_deps(
          merge_deps(($baseBom.dependencies // []); ($runtimeBom.dependencies // []));
          ($appBom.dependencies // [])
        )
        + [
          {
            ref: $containerRef,
            dependsOn: [
              ($baseC["bom-ref"]),
              ($runtimeC["bom-ref"]),
              ($appC["bom-ref"])
            ]
          }
        ]
        | merge_deps(.; [])
      ),
      compositions: [
        {
          aggregate: "complete",
          assemblies: [
            ($baseC["bom-ref"]),
            ($runtimeC["bom-ref"]),
            ($appC["bom-ref"])
          ],
          dependencies: [ $containerRef ]
        }
      ]
    }
  ' > "$OUT_BOM"
