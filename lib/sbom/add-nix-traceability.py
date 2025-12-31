#!/usr/bin/env python3
"""
Add Nix Traceability to Ecosystem Packages

This script identifies and links ecosystem packages (pkg:pypi, pkg:gem, etc.)
to their Nix build equivalents (pkg:nix/*), adding traceability properties and
deduplicating components.

Usage:
    python3 add-nix-traceability.py <sbom.json>
"""

import json
import re
import sys
from typing import Optional, Dict, List
from dataclasses import dataclass


@dataclass
class EcosystemPackage:
    """Ecosystem package with PURL info."""

    purl: str
    purl_type: str  # pypi, gem, maven, golang, etc.
    name: str  # Package name from PURL
    version: str  # Package version


def parse_purl(purl_str: str) -> Optional[EcosystemPackage]:
    """Parse package URL to extract type, name, and version."""
    if not purl_str:
        return None

    # Match pkg:type/name@version with optional query string
    match = re.match(r"^pkg:([^/]+)/(.+?)@([^?]+)", purl_str)
    if not match:
        return None

    purl_type, name, version = match.groups()

    # For Maven, extract artifact name from group/artifact format
    if purl_type == "maven" and "/" in name:
        name = name.split("/")[-1]

    return EcosystemPackage(
        purl=purl_str, purl_type=purl_type, name=name, version=version
    )


def normalize_name(name: str) -> str:
    """Normalize package name for matching (lowercase, remove hyphens/underscores)."""
    return name.lower().replace("-", "").replace("_", "")


def extract_base_name(nix_name: str) -> Optional[str]:
    """
    Extract base package name from Nix package name.

    Examples:
        python3.11-anyio -> anyio
        ruby3.3-cucumber -> cucumber
        python3-foo -> foo
    """
    patterns = [
        r"^python\d+(?:\.\d+)?-(.+)$",
        r"^ruby\d+(?:\.\d+)?-(.+)$",
        r"^perl\d+(?:\.\d+)?-(.+)$",
        r"^nodejs\d+(?:\.\d+)?-(.+)$",
    ]

    for pattern in patterns:
        match = re.match(pattern, nix_name)
        if match:
            return match.group(1)

    # No recognized pattern - return name as-is
    return nix_name


def find_nix_equivalent(
    eco_pkg: EcosystemPackage, nix_components: List[dict]
) -> Optional[dict]:
    """
    Find Nix component matching an ecosystem package.

    Mapping strategy:
    - Python: pypi/X@V -> pkg:nix/python3.11-X@V
    - Ruby: gem/X@V -> pkg:nix/ruby3.3-X@V
    - Others: Attempt direct name match (likely to fail for bundled types)
    """
    target_name = normalize_name(eco_pkg.name)
    target_version = eco_pkg.version

    for nix_comp in nix_components:
        nix_name = nix_comp.get("name", "")
        nix_version = nix_comp.get("version", "")

        if nix_version != target_version:
            continue

        # Extract base name from Nix package name
        base_name = extract_base_name(nix_name)
        if base_name and normalize_name(base_name) == target_name:
            return nix_comp

    return None


def add_traceability(component: dict, nix_component: dict) -> None:
    """Add Nix traceability properties and external references to ecosystem component."""
    # Extract Nix info from properties
    nix_props = {}
    for prop in nix_component.get("properties", []):
        nix_props[prop["name"]] = prop["value"]

    nix_output = nix_props.get("nix:output_path", "")
    nix_drv = nix_props.get("nix:drv_path", nix_component.get("bom-ref", ""))
    nix_purl = nix_component.get("purl", "")

    # Add external reference to Nix store output
    if nix_output:
        ext_refs = component.setdefault("externalReferences", [])
        ext_refs.append(
            {
                "type": "build-system",
                "url": f"nix:store:{nix_output}",
                "comment": "Nix derivation output",
            }
        )

    # Add Nix traceability properties
    props = component.setdefault("properties", [])

    if nix_purl:
        props.append({"name": "nix:purl", "value": nix_purl})
    if nix_drv:
        props.append({"name": "nix:drv", "value": nix_drv})
    if nix_output:
        props.append({"name": "nix:output", "value": nix_output})


def update_dependency_refs(
    dependencies: List[dict], ref_mapping: Dict[str, str]
) -> None:
    """Update dependency graph to use new bom-refs after deduplication."""
    for dep in dependencies:
        # Update ref if it's in the mapping
        old_ref = dep.get("ref")
        if old_ref in ref_mapping:
            dep["ref"] = ref_mapping[old_ref]

        # Update dependsOn references
        depends_on = dep.get("dependsOn", [])
        for i, dep_ref in enumerate(depends_on):
            if dep_ref in ref_mapping:
                depends_on[i] = ref_mapping[dep_ref]


def process_sbom(sbom: dict):
    """
    Process SBOM to add Nix traceability and deduplicate components.

    Returns: (mapped_count, unmapped_types_count, removed_count)
    """
    components = sbom.get("components", [])
    dependencies = sbom.get("dependencies", [])

    # Separate components by type
    nix_components = []
    ecosystem_components = []
    other_components = []

    for comp in components:
        purl = comp.get("purl", "")
        if purl.startswith("pkg:nix/"):
            nix_components.append(comp)
        elif purl.startswith("pkg:"):
            ecosystem_components.append(comp)
        else:
            other_components.append(comp)

    # Build mappings: ecosystem -> nix
    mappings: List = []  # List of (ecosystem_comp, nix_comp) tuples
    unmapped_types: Dict[str, List[str]] = {}  # Track unmapped ecosystem types

    for eco_comp in ecosystem_components:
        purl = eco_comp.get("purl", "")
        eco_pkg = parse_purl(purl)

        if not eco_pkg:
            continue

        nix_match = find_nix_equivalent(eco_pkg, nix_components)
        if nix_match:
            mappings.append((eco_comp, nix_match))
        else:
            # Track unmapped package type
            if eco_pkg.purl_type not in unmapped_types:
                unmapped_types[eco_pkg.purl_type] = []
            unmapped_types[eco_pkg.purl_type].append(eco_pkg.name)

    # Log unmapped packages (these will cause test failures)
    for purl_type, packages in unmapped_types.items():
        package_count = len(packages)
        print(
            f"[traceability] warning: {package_count} {purl_type} packages have no Nix equivalent",
            file=sys.stderr,
        )
        if package_count <= 5:
            print(f"  -> {', '.join(packages)}", file=sys.stderr)

    # Create ref mapping: nix_bom_ref -> ecosystem_bom_ref
    ref_mapping = {}
    nix_to_remove = set()

    for eco_comp, nix_comp in mappings:
        eco_ref = eco_comp.get("bom-ref")
        nix_ref = nix_comp.get("bom-ref")

        # Add traceability to ecosystem component
        add_traceability(eco_comp, nix_comp)

        # Map old Nix ref to new ecosystem ref
        ref_mapping[nix_ref] = eco_ref
        nix_to_remove.add(nix_ref)

    # Update dependency graph
    update_dependency_refs(dependencies, ref_mapping)

    # Remove duplicate Nix components
    sbom["components"] = [
        c for c in components if c.get("bom-ref") not in nix_to_remove
    ]

    return len(mappings), len(unmapped_types), len(nix_to_remove)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 add-nix-traceability.py <sbom.json>", file=sys.stderr)
        sys.exit(1)

    sbom_path = sys.argv[1]

    try:
        with open(sbom_path, "r") as f:
            sbom = json.load(f)
    except Exception as e:
        print(f"Error reading {sbom_path}: {e}", file=sys.stderr)
        sys.exit(1)

    # Process SBOM
    mapped, unmapped_types, removed = process_sbom(sbom)

    # Write back
    try:
        with open(sbom_path, "w") as f:
            json.dump(sbom, f, indent=2)
    except Exception as e:
        print(f"Error writing {sbom_path}: {e}", file=sys.stderr)
        sys.exit(1)

    # Report
    print(f"[traceability] mapped {mapped} ecosystem packages to Nix", file=sys.stderr)
    if unmapped_types:
        print(
            f"[traceability] {unmapped_types} ecosystem types have no Nix equivalents",
            file=sys.stderr,
        )
    print(f"[traceability] removed {removed} duplicate Nix components", file=sys.stderr)


if __name__ == "__main__":
    main()
