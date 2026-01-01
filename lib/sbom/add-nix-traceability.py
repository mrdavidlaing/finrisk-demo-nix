#!/usr/bin/env python3
"""
Add Nix Traceability to Ecosystem Packages

This script adds Nix build provenance and scope metadata to ecosystem packages (PyPI, Gem, etc.)
in CycloneDX SBOMs, enabling accurate vulnerability traceability and impact analysis.

Usage:
    python3 add-nix-traceability.py [--passthru-deps FILE] <sbom.json>
"""

import json
import re
import sys
import argparse
import os
from typing import Optional, Dict, List, Tuple
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


def load_passthru_deps(filepath: str) -> Dict[str, List[Dict]]:
    """
    Load passthru dependency information from JSON file.

    Returns dict with 'runtime' and 'dev-only' keys containing lists of packages.
    """
    if not filepath or not os.path.exists(filepath):
        return {"runtime": [], "dev-only": []}

    try:
        with open(filepath, "r") as f:
            data = json.load(f)
        return data
    except Exception as e:
        print(
            f"[traceability] warning: failed to load passthru deps: {e}",
            file=sys.stderr,
        )
        return {"runtime": [], "dev-only": []}


def find_nix_equivalent_from_passthru(
    eco_pkg: EcosystemPackage, passthru_deps: Dict[str, List[Dict]]
) -> Optional[Tuple[Dict, str]]:
    """
    Find Nix component from passthru dependency data.

    Returns: (component_info, scope) tuple, or None if not found.
    """
    target_name = normalize_name(eco_pkg.name)
    target_version = eco_pkg.version

    # Check runtime dependencies first, then dev-only
    for scope in ["runtime", "dev-only"]:
        for dep in passthru_deps.get(scope, []):
            dep_name = normalize_name(dep.get("name", ""))
            dep_version = dep.get("version", "")

            if dep_name == target_name and dep_version == target_version:
                return (dep, scope)

    return None


def add_traceability(component: dict, nix_info: Dict, scope: str) -> None:
    """
    Add Nix traceability properties and scope metadata to ecosystem component.

    Args:
        component: SBOM component dict to enhance
        nix_info: Nix package info from passthru (name, version, outPath, drvPath)
        scope: "runtime" or "dev-only"
    """
    # Generate Nix PURL from outPath
    # e.g., /nix/store/xxx-python3.11-fastapi-0.104.1 -> pkg:nix/python3.11-fastapi@0.104.1
    out_path = nix_info["outPath"]
    base_name = os.path.basename(out_path)

    # Extract version from the base name if possible
    # Format is typically: python3.11-fastapi-0.104.1 or ruby3.3-cucumber-9.2.1
    nix_purl = f"pkg:nix/{base_name}"

    # Add Nix properties
    props = component.setdefault("properties", [])
    props.append({"name": "nix:purl", "value": nix_purl})
    props.append({"name": "nix:drv", "value": nix_info["drvPath"]})
    props.append({"name": "nix:output", "value": out_path})

    # Add scope metadata
    props.append({"name": "sbom:scope", "value": scope})

    # Add component-level scope attribute for vulnerability scanners
    # CycloneDX spec: "required" = runtime, "excluded" = not in final product
    component["scope"] = "required" if scope == "runtime" else "excluded"

    # Add external reference to Nix store output
    ext_refs = component.setdefault("externalReferences", [])
    ext_refs.append(
        {
            "type": "build-system",
            "url": f"nix:store:{out_path}",
            "comment": "Nix derivation output",
        }
    )


def process_sbom(sbom: dict, passthru_deps: Dict[str, List[Dict]]):
    """
    Process SBOM to add Nix traceability and scope metadata.

    Args:
        sbom: CycloneDX SBOM dict
        passthru_deps: Passthru dependency info with runtime and dev-only scopes

    Returns: (mapped_count, unmapped_types_count)
    """
    components = sbom.get("components", [])

    # Find ecosystem components (those without nix: prefix)
    ecosystem_components = []
    for comp in components:
        purl = comp.get("purl", "")
        if purl.startswith("pkg:") and not purl.startswith("pkg:nix/"):
            ecosystem_components.append(comp)

    # Track mapping statistics
    mapped_count = 0
    unmapped_types: Dict[str, List[str]] = {}

    # Process each ecosystem component
    for eco_comp in ecosystem_components:
        eco_pkg = parse_purl(eco_comp.get("purl", ""))
        if not eco_pkg:
            continue

        # Try passthru-based matching
        if passthru_deps:
            result = find_nix_equivalent_from_passthru(eco_pkg, passthru_deps)
            if result:
                nix_info, scope = result
                add_traceability(eco_comp, nix_info, scope)
                mapped_count += 1
                continue

        # If no passthru match, track as unmapped
        if eco_pkg.purl_type not in unmapped_types:
            unmapped_types[eco_pkg.purl_type] = []
        unmapped_types[eco_pkg.purl_type].append(eco_pkg.name)

    # Log unmapped packages
    for purl_type, packages in unmapped_types.items():
        print(
            f"[traceability] warning: {len(packages)} {purl_type} packages have no passthru match",
            file=sys.stderr,
        )
        if len(packages) <= 5:
            print(f"  -> {', '.join(packages)}", file=sys.stderr)

    return mapped_count, len(unmapped_types)


def main():
    parser = argparse.ArgumentParser(
        description="Add Nix traceability to ecosystem packages in SBOMs"
    )
    parser.add_argument("sbom_file", help="Path to SBOM file")
    parser.add_argument(
        "--passthru-deps", help="JSON file with passthru dependency information"
    )
    args = parser.parse_args()

    # Load SBOM
    try:
        with open(args.sbom_file, "r") as f:
            sbom = json.load(f)
    except Exception as e:
        print(f"Error reading {args.sbom_file}: {e}", file=sys.stderr)
        sys.exit(1)

    # Load passthru dependencies
    passthru_deps = load_passthru_deps(args.passthru_deps)

    # Process SBOM
    mapped, unmapped_types = process_sbom(sbom, passthru_deps)

    # Write back
    try:
        with open(args.sbom_file, "w") as f:
            json.dump(sbom, f, indent=2)
    except Exception as e:
        print(f"Error writing {args.sbom_file}: {e}", file=sys.stderr)
        sys.exit(1)

    # Report
    print(f"[traceability] mapped {mapped} ecosystem packages to Nix", file=sys.stderr)
    if unmapped_types:
        print(
            f"[traceability] {unmapped_types} ecosystem types have no passthru match",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
