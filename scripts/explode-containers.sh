#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "=== Container Filesystem Explorer ==="

if [ ! -d "result" ] || [ -z "$(ls -A result/*.tar.gz 2>/dev/null)" ]; then
    echo "Building Docker images..."
    nix build .#all-images
fi

echo "Cleaning tmp/containers..."
if [ -d tmp/containers ]; then
    chmod -R 755 tmp/containers 2>/dev/null || true
    rm -rf tmp/containers
fi
mkdir -p tmp/containers

echo "Extracting container filesystems..."
for tarfile in result/*.tar.gz; do
    if [ -f "$tarfile" ]; then
        service=$(basename "$tarfile" .tar.gz | sed 's/transferx-//')
        echo "  Extracting $service..."
        mkdir -p "tmp/containers/$service"
        tar -xzf "$tarfile" -C "tmp/containers/$service"
        
        # Ensure the extracted image directory is writable (some images make . read-only)
        chmod -R u+w "tmp/containers/$service"

        echo "    Extracting rootfs..."
        mkdir -p "tmp/containers/$service/rootfs"
        
        if command -v jq >/dev/null 2>&1; then
            layers=$(jq -r '.[0].Layers[]' "tmp/containers/$service/manifest.json")
            for layer in $layers; do
                layer_path="tmp/containers/$service/$layer"
                if [ -f "$layer_path" ]; then
                    # Ensure destination is writable
                    chmod -R u+w "tmp/containers/$service/rootfs"
                    
                    # Pre-create nix/store to avoid permission issues
                    mkdir -p "tmp/containers/$service/rootfs/nix/store"
                    
                    # Extract with --no-overwrite-dir and --delay-directory-restore to handle permissions
                    tar -xf "$layer_path" -C "tmp/containers/$service/rootfs" --no-overwrite-dir --delay-directory-restore
                fi
            done
            # Final chmod to ensure files are modifiable/deletable
            chmod -R u+w "tmp/containers/$service/rootfs"
        else
            echo "    Warning: jq not found, cannot extract layers."
        fi
    fi
done

echo ""
echo "Done! Filesystems extracted to tmp/containers/"
echo "Root filesystems available in tmp/containers/*/rootfs/"
echo ""
echo "To explore in VS Code:"
echo "  code tmp/containers"
