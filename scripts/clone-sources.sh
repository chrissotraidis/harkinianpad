#!/usr/bin/env bash
# Fetch the upstream source trees this project builds from, into ./sources/
# (git-ignored). Pins match the investigation in docs/ (see the revision
# table at the top of docs/ios-feasibility-and-implementation-plan.md).
#
# Usage:
#   scripts/clone-sources.sh            # clone Shipwright + submodules
#   scripts/clone-sources.sh --latest   # track upstream HEADs instead of pins
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/sources"
mkdir -p "$SRC"

# Investigated revisions (2026-07-24/25). Shipwright's own .gitmodules pins
# libultraship (port-maintenance), ZAPDTR, and OTRExporter — cloning with
# --recurse-submodules reproduces the exact investigated stack when the
# Shipwright commit below is checked out.
SHIPWRIGHT_REPO="https://github.com/HarbourMasters/Shipwright.git"
SHIPWRIGHT_PIN="da4e6dc3321bda48a313b162261156580bc376f4"

LATEST=0
[ "${1:-}" = "--latest" ] && LATEST=1

if [ ! -d "$SRC/Shipwright/.git" ]; then
    echo "==> Cloning Shipwright (this pulls libultraship/ZAPDTR/OTRExporter submodules)…"
    git clone --recurse-submodules --shallow-submodules "$SHIPWRIGHT_REPO" "$SRC/Shipwright"
fi

cd "$SRC/Shipwright"
if [ "$LATEST" = "1" ]; then
    echo "==> Updating to upstream HEAD…"
    git fetch origin && git checkout origin/HEAD --detach
else
    echo "==> Checking out investigated pin $SHIPWRIGHT_PIN…"
    git fetch origin "$SHIPWRIGHT_PIN" || git fetch origin
    git checkout "$SHIPWRIGHT_PIN" --detach
fi
git submodule update --init --recursive

echo
echo "Done. Source tree: $SRC/Shipwright"
echo "libultraship submodule: $(git -C libultraship rev-parse --short HEAD)"
echo "Next: scripts/configure-ios.sh (requires macOS + Xcode)"
