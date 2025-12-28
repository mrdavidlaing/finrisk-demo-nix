#!/usr/bin/env python3
"""
Layer Tagger - Add layer provenance tags to CycloneDX SBOM components

Adds a 'layer' property to all components indicating their layer:
- base: Base system components
- runtime: Runtime-specific components (node, java, python, etc.)
- app: Application-specific components

Usage:
    python3 layer-tagger.py <layer> <sbom1.json> [<sbom2.json> ...]

Arguments:
    layer: Layer name (base, runtime, or app)
    sbom files: One or more SBOM files to tag

Example:
    python3 layer-tagger.py base base.cdx.json
    python3 layer-tagger.py runtime runtime-node.cdx.json runtime-java.cdx.json
    python3 layer-tagger.py app app-*.cdx.json
"""

import json
import sys


VALID_LAYERS = ['base', 'runtime', 'app']


def tag_sbom(sbom_path, layer_name):
    """Add layer property to all components in an SBOM."""
    try:
        with open(sbom_path) as f:
            sbom = json.load(f)
    except Exception as e:
        print(f"Error reading {sbom_path}: {e}", file=sys.stderr)
        return False

    # Tag metadata.component if it exists
    tagged_count = 0
    metadata = sbom.get('metadata', {})
    metadata_component = metadata.get('component')
    if metadata_component:
        if 'properties' not in metadata_component:
            metadata_component['properties'] = []

        has_layer = any(
            p.get('name') == 'layer'
            for p in metadata_component['properties']
        )

        if not has_layer:
            metadata_component['properties'].append({
                'name': 'layer',
                'value': layer_name
            })
            tagged_count += 1

    # Tag all components in the components array
    for component in sbom.get('components', []):
        # Initialize properties array if it doesn't exist
        if 'properties' not in component:
            component['properties'] = []

        # Check if layer property already exists
        has_layer = any(
            p.get('name') == 'layer'
            for p in component['properties']
        )

        # Add layer property if it doesn't exist
        if not has_layer:
            component['properties'].append({
                'name': 'layer',
                'value': layer_name
            })
            tagged_count += 1

    # Write back
    try:
        with open(sbom_path, 'w') as f:
            json.dump(sbom, f, indent=2)
    except Exception as e:
        print(f"Error writing {sbom_path}: {e}", file=sys.stderr)
        return False

    if tagged_count > 0:
        print(f"Tagged {tagged_count} component(s) with layer={layer_name} in {sbom_path}", file=sys.stderr)

    return True


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 layer-tagger.py <layer> <sbom1.json> [<sbom2.json> ...]", file=sys.stderr)
        print(f"  layer: One of {', '.join(VALID_LAYERS)}", file=sys.stderr)
        sys.exit(1)

    layer_name = sys.argv[1]
    if layer_name not in VALID_LAYERS:
        print(f"Error: Invalid layer '{layer_name}'. Must be one of: {', '.join(VALID_LAYERS)}", file=sys.stderr)
        sys.exit(1)

    success = True
    for sbom_path in sys.argv[2:]:
        if not tag_sbom(sbom_path, layer_name):
            success = False

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
