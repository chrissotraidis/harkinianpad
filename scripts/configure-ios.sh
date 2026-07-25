#!/usr/bin/env bash
# Configure the iOS Xcode project for Ship of Harkinian.
#
# STATUS: this invocation matches libultraship's own iOS CI
# (.github/workflows/build-validation.yml) and configures the LUS library
# successfully. The full SoH app is EXPECTED TO FAIL configure/link today —
# that is work items 1-3 of docs/ios-feasibility-and-implementation-plan.md
# (missing iOS arm in SoH's CMake, CoreAudio compile gating, macOS-fullscreen
# link gap). This script exists so the failure is reproducible and so the
# invocation is settled from day one.
#
# Requires: macOS, Xcode + command line tools, CMake >= 3.24.
#
# Usage:
#   scripts/configure-ios.sh                 # configure LUS alone (works today)
#   scripts/configure-ios.sh --soh           # attempt full SoH app (expected to fail until WI-1..3 land)
#   BUNDLE_ID=com.example.soh DEVELOPMENT_TEAM=ABCDE12345 scripts/configure-ios.sh --soh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/sources/Shipwright"
DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-14.0}"   # LUS CI value; real floor TBD (open question Q10)
BUNDLE_ID="${BUNDLE_ID:-com.example.harkinianpad}"

if [ ! -d "$SRC" ]; then
    echo "sources/Shipwright not found — run scripts/clone-sources.sh first." >&2
    exit 1
fi

TARGET_DIR="$SRC/libultraship"
BUILD_DIR="$ROOT/build-ios-lus"
if [ "${1:-}" = "--soh" ]; then
    TARGET_DIR="$SRC"
    BUILD_DIR="$ROOT/build-ios-soh"
    echo "NOTE: full-app iOS configure is expected to fail until plan work items 1-3 are implemented."
fi

EXTRA_ARGS=()
[ -n "${DEVELOPMENT_TEAM:-}" ] && EXTRA_ARGS+=("-DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM" "-DSIGN_LIBRARY=ON")

cmake --no-warn-unused-cli \
    -S "$TARGET_DIR" -B "$BUILD_DIR" \
    -GXcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
    -DCMAKE_BUILD_TYPE:STRING=Release \
    -DBUNDLE_ID="$BUNDLE_ID" \
    "${EXTRA_ARGS[@]}"

echo
echo "Configured: $BUILD_DIR (open the generated .xcodeproj in Xcode, or:"
echo "  cmake --build \"$BUILD_DIR\" --config Release -- -destination 'generic/platform=iOS')"
