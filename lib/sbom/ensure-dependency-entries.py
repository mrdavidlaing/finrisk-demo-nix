#!/usr/bin/env python3
"""
Dependency Entry Ensurer - Ensure all components have dependency entries

For Dependency Track compatibility, all components should have a corresponding
entry in the dependencies array, even if the dependsOn array is empty.

Usage:
    python3 ensure-dependency-entries.py <sbom1.json> [<sbom2.json> ...]
"""

import json
import sys


def ensure_dependency_entries(sbom_path):
    """Ensure all components have dependency entries in a single SBOM."""
    try:
        with open(sbom_path) as f:
            sbom = json.load(f)
    except Exception as e:
        print(f"Error reading {sbom_path}: {e}", file=sys.stderr)
        return False

    # Collect all component bom-refs
    component_refs = set()
    for component in sbom.get('components', []):
        bom_ref = component.get('bom-ref')
        if bom_ref:
            component_refs.add(bom_ref)

    # Also include metadata component if it has a bom-ref
    metadata_ref = sbom.get('metadata', {}).get('component', {}).get('bom-ref')
    if metadata_ref:
        component_refs.add(metadata_ref)

    # Collect existing dependency refs
    existing_dep_refs = set()
    dependencies = sbom.get('dependencies', [])
    for dep in dependencies:
        ref = dep.get('ref')
        if ref:
            existing_dep_refs.add(ref)

    # Find missing dependency entries
    missing_refs = component_refs - existing_dep_refs

    # Add missing dependency entries with empty dependsOn arrays
    added_count = 0
    for ref in missing_refs:
        dependencies.append({
            'ref': ref,
            'dependsOn': []
        })
        added_count += 1

    if added_count > 0:
        sbom['dependencies'] = dependencies

        # Write back
        try:
            with open(sbom_path, 'w') as f:
                json.dump(sbom, f, indent=2)
        except Exception as e:
            print(f"Error writing {sbom_path}: {e}", file=sys.stderr)
            return False

        print(f"Added {added_count} missing dependency entry(ies) in {sbom_path}", file=sys.stderr)

    return True


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 ensure-dependency-entries.py <sbom1.json> [<sbom2.json> ...]", file=sys.stderr)
        sys.exit(1)

    success = True
    for sbom_path in sys.argv[1:]:
        if not ensure_dependency_entries(sbom_path):
            success = False

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
