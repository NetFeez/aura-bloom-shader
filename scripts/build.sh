#!/usr/bin/env bash
set -euo pipefail

# Pack the distributable .hshader at the workspace root, next to the signing folder.
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
root="$(dirname "$repo")"
cd "$repo"

id="$(sed -n 's/^id = "\([^"]*\)"/\1/p' horizon-shaders.toml | head -1)"
version="$(sed -n 's/^version = "\([^"]*\)"/\1/p' horizon-shaders.toml | head -1)"
artifact="$root/${id}-${version}.hshader"

if [ -n "${HORIZON_SHADER:-}" ]; then
    shader="$HORIZON_SHADER"
elif command -v horizon-shader >/dev/null 2>&1; then
    shader="horizon-shader"
else
    shader="$root/horizon/target/debug/horizon-shader"
fi

if [ ! -x "$shader" ] && ! command -v "$shader" >/dev/null 2>&1; then
    echo "horizon-shader not found; set HORIZON_SHADER to its path" >&2
    exit 1
fi

stage="$(mktemp -d /tmp/opencode/aurora-bloom-stage.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
cp horizon-shaders.toml *.wgsl icon.png README.md LICENSE "$stage"/

"$shader" check "$stage"
"$shader" pack "$stage" --out "$artifact"
"$shader" check "$artifact"

echo "Built $artifact"
sha256sum "$artifact"
