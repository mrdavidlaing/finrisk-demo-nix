#!/usr/bin/env python3
"""
CPE Fixer - Fix CPE vendors and normalize versions in CycloneDX SBOMs

Fixes:
- Incorrect CPE vendors (e.g., glibc→gnu, bash→gnu)
- Nix version suffixes (e.g., 2.40-66→2.40)

Usage:
    python3 cpe-fixer.py <sbom1.json> [<sbom2.json> ...]
"""

import json
import re
import sys
from pathlib import Path

# Try to import yaml, but make mappings optional if not available
try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False
    print("Warning: PyYAML not available, using built-in vendor mappings", file=sys.stderr)

# Built-in vendor mappings (fallback if YAML not available or file not found)
BUILTIN_VENDOR_MAPPINGS = {
    # GNU Components
    'glibc': 'gnu',
    'bash': 'gnu',
    'gcc': 'gnu',
    'binutils': 'gnu',
    'coreutils': 'gnu',
    'findutils': 'gnu',
    'gawk': 'gnu',
    'grep': 'gnu',
    'gzip': 'gnu',
    'make': 'gnu',
    'sed': 'gnu',
    'tar': 'gnu',
    # OpenSSL
    'openssl': 'openssl',
    # Programming Languages
    'python': 'python',
    'python3': 'python',
    'nodejs': 'nodejs',
    'go': 'golang',
    'dotnet': 'microsoft',
    # Common Libraries
    'zlib': 'zlib',
    'curl': 'haxx',
    'libxml2': 'xmlsoft',
    'sqlite': 'sqlite',
    # System Components
    'systemd': 'freedesktop',
    'dbus': 'freedesktop',
}


def load_vendor_mappings():
    """Load vendor mappings from YAML file or use built-in mappings."""
    if not HAS_YAML:
        return BUILTIN_VENDOR_MAPPINGS

    # Try to find the mappings file
    possible_paths = [
        Path('compliance/sbom-tests/fixtures/nvd_cpe_mappings.yml'),
        Path(__file__).parent.parent.parent / 'compliance/sbom-tests/fixtures/nvd_cpe_mappings.yml',
    ]

    for yaml_path in possible_paths:
        if yaml_path.exists():
            try:
                with open(yaml_path) as f:
                    data = yaml.safe_load(f)
                    return data.get('vendor_mappings', BUILTIN_VENDOR_MAPPINGS)
            except Exception as e:
                print(f"Warning: Failed to load {yaml_path}: {e}", file=sys.stderr)
                break

    return BUILTIN_VENDOR_MAPPINGS


def normalize_version(version):
    """
    Remove Nix package suffix from version.
    Example: 2.40-66 -> 2.40
    """
    if not version or not isinstance(version, str):
        return version

    # Remove Nix suffix pattern: -[0-9]+$
    normalized = re.sub(r'-\d+$', '', version)
    return normalized


def fix_cpe(cpe_string, component_name, vendor_mappings):
    """
    Fix CPE vendor and normalize version.

    CPE Format: cpe:2.3:part:vendor:product:version:update:edition:language:sw_edition:target_sw:target_hw:other
    """
    if not cpe_string or not isinstance(cpe_string, str):
        return cpe_string

    if not cpe_string.startswith('cpe:2.3:'):
        return cpe_string

    # Parse CPE
    parts = cpe_string.split(':')
    if len(parts) < 6:
        return cpe_string

    # Fix vendor (index 3)
    product = component_name.lower() if component_name else ''
    if product in vendor_mappings:
        parts[3] = vendor_mappings[product]

    # Fix version (index 5)
    parts[5] = normalize_version(parts[5])

    return ':'.join(parts)


def split_nix_name_version(name):
    """
    Split a Nix package name that has version embedded.

    Examples:
        python3-3.11.14 -> (python3, 3.11.14)
        krb5-1.22.1 -> (krb5, 1.22.1)
        openjdk-17.0.17+10 -> (openjdk, 17.0.17+10)
        systemd-minimal-258.2 -> (systemd-minimal, 258.2)
        bash -> (bash, None)  # no version
    """
    if not name:
        return name, None

    # Pattern: name-version where version starts with a digit
    # Handles versions like: 1.2.3, 1.2.3-66, 17.0.17+10
    match = re.match(r'^(.+?)-(\d+[\d.+\-]+)$', name)
    if match:
        return match.group(1), match.group(2)

    return name, None


def fix_nix_versioned_name(component):
    """
    Fix Nix components where version is embedded in the name.

    Examples: python3-3.11.14, krb5-1.22.1, openjdk-17.0.17+10
    These have empty version fields and need to be split.
    """
    name = component.get('name', '')
    version = component.get('version', '')

    # Only process if version is empty and name looks like it has a version
    if version or not name:
        return False

    # Try to split name-version
    base_name, extracted_version = split_nix_name_version(name)

    if not extracted_version:
        return False

    # Update component
    component['name'] = base_name
    component['version'] = extracted_version

    # Fix PURL to use split name and version
    if 'purl' in component and component['purl']:
        # Change pkg:nix/python3-3.11.14 to pkg:nix/python3@3.11.14
        component['purl'] = f"pkg:nix/{base_name}@{extracted_version}"

    # Fix CPE to use split name and version
    if 'cpe' in component and component['cpe']:
        cpe = component['cpe']
        if cpe.startswith('cpe:2.3:'):
            parts = cpe.split(':')
            if len(parts) >= 6:
                # Update vendor (index 3), product (index 4) and version (index 5)
                # Set vendor same as product initially, will be corrected by fix_cpe later
                parts[3] = base_name
                parts[4] = base_name
                parts[5] = extracted_version
                component['cpe'] = ':'.join(parts)

    # Update bom-ref if it includes the old name
    if 'bom-ref' in component:
        bom_ref = component['bom-ref']
        if name in bom_ref:
            component['bom-ref'] = bom_ref.replace(name, f"{base_name}-{extracted_version}")

    return True


def fix_transferx_component(component):
    """
    Fix transferx-* components that lack versions.

    These are our build environment components (base-set, runtime-*) which don't have
    semantic versions. We assign them version "1.0.0" and regenerate CPE/PURL.
    """
    name = component.get('name', '')
    if not name.startswith('transferx-'):
        return False

    # Only fix if version is missing or empty
    version = component.get('version', '')
    if version:
        return False

    # Add version
    component['version'] = '1.0.0'

    # Fix PURL to include version
    if 'purl' in component and component['purl']:
        # Change pkg:nix/transferx-base-set to pkg:nix/transferx-base-set@1.0.0
        if '@' not in component['purl']:
            component['purl'] = f"{component['purl']}@1.0.0"

    # Fix CPE to include version
    if 'cpe' in component and component['cpe']:
        cpe = component['cpe']
        if cpe.startswith('cpe:2.3:'):
            parts = cpe.split(':')
            if len(parts) >= 6:
                # Set version field (index 5)
                parts[5] = '1.0.0'
                component['cpe'] = ':'.join(parts)

    return True


def fix_missing_version(component):
    """
    Fix any remaining components that lack versions.

    This is a catch-all for components like gemfile-and-lockfile, smoke-tests-gems, etc.
    that don't have semantic versions. We assign them version "0.0.0".
    """
    name = component.get('name', '')
    version = component.get('version', '')

    # Only fix if version is missing or empty
    if version or not name:
        return False

    # Add default version
    component['version'] = '0.0.0'

    # Fix PURL to include version
    if 'purl' in component and component['purl']:
        if '@' not in component['purl']:
            component['purl'] = f"{component['purl']}@0.0.0"

    # Fix CPE to include version
    if 'cpe' in component and component['cpe']:
        cpe = component['cpe']
        if cpe.startswith('cpe:2.3:'):
            parts = cpe.split(':')
            if len(parts) >= 6:
                # Set version field (index 5)
                parts[5] = '0.0.0'
                component['cpe'] = ':'.join(parts)

    return True


def fix_sbom(sbom_path, vendor_mappings):
    """Fix CPEs in a single SBOM file."""
    try:
        with open(sbom_path) as f:
            sbom = json.load(f)
    except Exception as e:
        print(f"Error reading {sbom_path}: {e}", file=sys.stderr)
        return False

    # Fix components
    fixed_cpe_count = 0
    fixed_transferx_count = 0
    fixed_versioned_name_count = 0
    fixed_missing_version_count = 0

    for component in sbom.get('components', []):
        # Fix Nix components with version in name (e.g., python3-3.11.14)
        if fix_nix_versioned_name(component):
            fixed_versioned_name_count += 1

        # Fix transferx-* components (adds versions)
        if fix_transferx_component(component):
            fixed_transferx_count += 1

        # Fix any remaining components without versions (catch-all)
        if fix_missing_version(component):
            fixed_missing_version_count += 1

        # Then fix CPEs (uses the new version if applicable)
        if 'cpe' in component:
            original_cpe = component['cpe']
            component_name = component.get('name', '')
            fixed_cpe = fix_cpe(original_cpe, component_name, vendor_mappings)

            if fixed_cpe != original_cpe:
                component['cpe'] = fixed_cpe
                fixed_cpe_count += 1

    # Write back
    try:
        with open(sbom_path, 'w') as f:
            json.dump(sbom, f, indent=2)
    except Exception as e:
        print(f"Error writing {sbom_path}: {e}", file=sys.stderr)
        return False

    if fixed_versioned_name_count > 0:
        print(f"Fixed {fixed_versioned_name_count} versioned-name component(s) in {sbom_path}", file=sys.stderr)
    if fixed_transferx_count > 0:
        print(f"Fixed {fixed_transferx_count} transferx component(s) in {sbom_path}", file=sys.stderr)
    if fixed_missing_version_count > 0:
        print(f"Fixed {fixed_missing_version_count} missing-version component(s) in {sbom_path}", file=sys.stderr)
    if fixed_cpe_count > 0:
        print(f"Fixed {fixed_cpe_count} CPE(s) in {sbom_path}", file=sys.stderr)

    return True


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 cpe-fixer.py <sbom1.json> [<sbom2.json> ...]", file=sys.stderr)
        sys.exit(1)

    vendor_mappings = load_vendor_mappings()

    success = True
    for sbom_path in sys.argv[1:]:
        if not fix_sbom(sbom_path, vendor_mappings):
            success = False

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
