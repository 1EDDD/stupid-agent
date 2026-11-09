#!/bin/bash
# Vendors the swift pi package (github.com/stephancill/swift-pi) into Vendor/SwiftPi at a release tag.
# stupid-app builds only local sources, not remote package products, so the sources are copied rather than
# resolved by SwiftPM.
set -euo pipefail

TAG="${1:-v0.1.1}"
REPO="https://github.com/stephancill/swift-pi.git"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Vendor/SwiftPi"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$TAG" "$REPO" "$WORK/repo"
commit="$(git -C "$WORK/repo" rev-parse HEAD)"

rm -rf "$OUT"
mkdir -p "$OUT"
cp -R "$WORK/repo/Sources" "$OUT/Sources"
cp "$WORK/repo/LICENSE" "$OUT/LICENSE"
printf '%s %s\n' "$TAG" "$commit" > "$OUT/VERSION"
echo "Vendored swift pi $TAG ($commit)"
