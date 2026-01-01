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
    chmod -Rf u+w tmp/containers 2>/dev/null || true
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
    fi
done

echo "Making directories writable..."
chmod -Rf u+w tmp/containers 2>/dev/null || true

echo "Extracting layer.tar files..."
while IFS= read -r layertar; do
    hash_dir=$(dirname "$layertar")
    service=$(basename "$(dirname "$hash_dir")")
    echo "  Extracting layers for $service..."
    mkdir -p "tmp/containers/$service/layer-contents"
    tar -xf "$layertar" -C "tmp/containers/$service/layer-contents" --transform 's|^\./||' --transform 's|^nix/store/||' --no-same-owner -m 2>/dev/null || true
done < <(find tmp/containers -mindepth 2 -name "layer.tar" -type f)

echo ""
echo "Done! Filesystems extracted to tmp/containers/"
echo ""
echo "To explore in VS Code:"
echo "  code tmp/containers"
