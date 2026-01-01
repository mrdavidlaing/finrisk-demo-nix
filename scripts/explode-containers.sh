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
rm -rf tmp/containers
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

echo ""
echo "Done! Filesystems extracted to tmp/containers/"
echo ""
echo "To explore in VS Code:"
echo "  code tmp/containers"
