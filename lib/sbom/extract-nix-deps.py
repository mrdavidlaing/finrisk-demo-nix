#!/usr/bin/env python3
"""
Extract Nix package metadata from store paths

Input: runtime_paths dev_paths (as bash variables)
Output: JSON with runtime, dev-only, all arrays with name/version/out_path/drv_path

Note: Uses "out_path" and "drv_path" field names (not "outPath"/"drvPath") to be consistent
with the Nix passthru data format which avoids Nix's derivation coercion behavior.
"""

import json
import sys


def extract_metadata(paths_str):
    """Extract name/version/out_path/drv_path from Nix store paths"""
    if not paths_str:
        return []

    paths = paths_str.split()
    results = []

    for path in paths:
        # Extract basename
        basename = path.split("/")[-1] if "/" in path else path
        if not basename:
            continue

        # Remove store hash prefix: hash-name-version -> name-version
        # The hash is 32 chars, so we skip it
        if len(basename) > 34:
            clean_name = basename[33:]  # Skip "hash-"
        else:
            clean_name = basename

        # Split on last hyphen: name-version -> name, version
        # Examples:
        #   python3.11-fastapi-0.104.1 -> python3.11-fastapi, 0.104.1
        #   python3.11-pytest-7.4.4 -> python3.11-pytest, 7.4.4
        if "-" in clean_name:
            parts = clean_name.rsplit("-", 1)
            if len(parts) == 2:
                name = parts[0]
                version = parts[1]
            else:
                # More than one hyphen, split on last one
                name = clean_name.rsplit("-", 1)[0]
                version = clean_name.rsplit("-", 1)[-1]
        else:
            name = clean_name
            version = "unknown"

        # drv path cannot be determined from output path alone
        # (this is a limitation of this fallback approach)
        drv_path = ""

        # Use "out_path" and "drv_path" field names to match passthru format
        results.append(
            {"name": name, "version": version, "out_path": path, "drv_path": drv_path}
        )

    return results


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <runtime_paths> <dev_paths> <output_file>")
        sys.exit(1)

    runtime_paths_str = sys.argv[1]
    dev_paths_str = sys.argv[2]
    output_file = sys.argv[3]

    # Extract metadata
    runtime = extract_metadata(runtime_paths_str)
    dev_only = extract_metadata(dev_paths_str)

    # Combine and deduplicate
    all = runtime + dev_only
    seen = set()
    unique_all = []
    for item in all:
        key = (item["name"], item["version"])
        if key not in seen:
            seen.add(key)
            unique_all.append(item)

    # Write output
    output = {"runtime": runtime, "dev-only": dev_only, "all": unique_all}

    with open(output_file, "w") as f:
        json.dump(output, f, indent=2)

    print(f"Extracted {len(runtime)} runtime deps, {len(dev_only)} dev-only deps")


if __name__ == "__main__":
    main()
