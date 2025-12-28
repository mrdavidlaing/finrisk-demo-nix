#!/usr/bin/env python3
"""
SBOM Deduplicator - Ensure unique bom-refs within CycloneDX SBOMs

Finds duplicate bom-refs and renames them with suffixes (-2, -3, etc.)
to ensure all bom-refs are unique within the SBOM.

Usage:
    python3 dedup.py <sbom1.json> [<sbom2.json> ...]
"""

import json
import sys
from collections import defaultdict


def deduplicate_sbom(sbom_path):
    """Deduplicate bom-refs within a single SBOM."""
    try:
        with open(sbom_path) as f:
            sbom = json.load(f)
    except Exception as e:
        print(f"Error reading {sbom_path}: {e}", file=sys.stderr)
        return False

    # Count occurrences of each bom-ref
    ref_counts = defaultdict(int)
    for component in sbom.get('components', []):
        bom_ref = component.get('bom-ref')
        if bom_ref:
            ref_counts[bom_ref] += 1

    # Find duplicates
    duplicates = {ref: count for ref, count in ref_counts.items() if count > 1}

    if not duplicates:
        return True  # No duplicates

    # Track which occurrence we're on for each duplicate ref
    ref_counters = defaultdict(int)

    # Rename duplicate bom-refs
    for component in sbom.get('components', []):
        bom_ref = component.get('bom-ref')
        if bom_ref and bom_ref in duplicates:
            ref_counters[bom_ref] += 1
            # First occurrence keeps original name, rest get suffixes
            if ref_counters[bom_ref] > 1:
                new_ref = f"{bom_ref}-{ref_counters[bom_ref]}"
                component['bom-ref'] = new_ref

    # Write back
    try:
        with open(sbom_path, 'w') as f:
            json.dump(sbom, f, indent=2)
    except Exception as e:
        print(f"Error writing {sbom_path}: {e}", file=sys.stderr)
        return False

    total_renamed = sum(count - 1 for count in duplicates.values())
    if total_renamed > 0:
        print(f"Renamed {total_renamed} duplicate bom-ref(s) in {sbom_path}", file=sys.stderr)

    return True


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 dedup.py <sbom1.json> [<sbom2.json> ...]", file=sys.stderr)
        sys.exit(1)

    success = True
    for sbom_path in sys.argv[1:]:
        if not deduplicate_sbom(sbom_path):
            success = False

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
