#!/usr/bin/env python3
"""
Component Filter - Remove non-software components from CycloneDX SBOMs

Filters out:
- GitHub workflow files (.github/workflows/*)
- CI configuration files (.gitlab-ci.yml, .travis.yml, .circleci/*)
- Other build/dev infrastructure

Usage:
    python3 component-filter.py <sbom1.json> [<sbom2.json> ...]
"""

import json
import re
import sys


# Patterns for components to filter out
# These match anywhere in the component name/path
FILTER_PATTERNS = [
    r'\.github/workflows/',
    r'\.github/actions/',
    r'\.gitlab-ci\.yml$',
    r'\.travis\.yml$',
    r'\.circleci/',
    r'\.jenkins/',
    r'/Jenkinsfile$',
    r'\.drone\.yml$',
    r'azure-pipelines\.yml$',
    r'bitbucket-pipelines\.yml$',
    r'\.buildkite/',
]


def should_filter_component(component):
    """
    Determine if a component should be filtered out.

    Returns True if the component name matches any filter pattern.
    """
    name = component.get('name', '')
    if not name:
        return False

    for pattern in FILTER_PATTERNS:
        if re.search(pattern, name):
            return True

    return False


def filter_sbom(sbom_path):
    """Filter components from a single SBOM file."""
    try:
        with open(sbom_path) as f:
            sbom = json.load(f)
    except Exception as e:
        print(f"Error reading {sbom_path}: {e}", file=sys.stderr)
        return False

    # Count components before filtering
    original_count = len(sbom.get('components', []))

    # Filter components
    filtered_components = [
        c for c in sbom.get('components', [])
        if not should_filter_component(c)
    ]

    sbom['components'] = filtered_components

    # Build set of valid bom-refs after filtering
    valid_refs = set(c.get('bom-ref') for c in filtered_components if c.get('bom-ref'))

    # Also include metadata component bom-ref (e.g., container:service-name)
    metadata_ref = sbom.get('metadata', {}).get('component', {}).get('bom-ref')
    if metadata_ref:
        valid_refs.add(metadata_ref)

    # Clean up orphaned dependencies
    # Remove dependencies that reference filtered components
    if 'dependencies' in sbom:
        cleaned_deps = []
        for dep in sbom.get('dependencies', []):
            ref = dep.get('ref')
            # Keep dependency if ref is valid
            if ref in valid_refs or not ref:
                # Also filter dependsOn array
                depends_on = dep.get('dependsOn', [])
                cleaned_depends_on = [r for r in depends_on if r in valid_refs]
                cleaned_deps.append({
                    'ref': ref,
                    'dependsOn': cleaned_depends_on
                })

        sbom['dependencies'] = cleaned_deps

    # Calculate filtered count
    filtered_count = original_count - len(filtered_components)

    # Write back
    try:
        with open(sbom_path, 'w') as f:
            json.dump(sbom, f, indent=2)
    except Exception as e:
        print(f"Error writing {sbom_path}: {e}", file=sys.stderr)
        return False

    if filtered_count > 0:
        print(f"Filtered {filtered_count} component(s) from {sbom_path}", file=sys.stderr)

    return True


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 component-filter.py <sbom1.json> [<sbom2.json> ...]", file=sys.stderr)
        sys.exit(1)

    success = True
    for sbom_path in sys.argv[1:]:
        if not filter_sbom(sbom_path):
            success = False

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
