#!/usr/bin/env bash
# Generate Ship of Harkinian's ROM-free soh.o2r port archive on the macOS host.
#
# This archive contains Shipwright's custom assets and shaders. It does not
# read a ROM. The generated file remains ignored and is copied into iOS app
# bundles by the maintained Shipwright patch.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/sources/Shipwright"
BUILD_DIR="$ROOT/build-host-soh"
ARCHIVE="$BUILD_DIR/soh/soh.o2r"

if [ ! -d "$SRC" ]; then
    echo "sources/Shipwright not found — run scripts/clone-sources.sh first." >&2
    exit 1
fi

cmake -S "$SRC" -B "$BUILD_DIR" -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_SCRIPTING=OFF
cmake --build "$BUILD_DIR" --target GenerateSohOtr

if [ ! -f "$ARCHIVE" ]; then
    echo "Expected archive was not generated: $ARCHIVE" >&2
    exit 1
fi

archive_entries="$(unzip -Z1 "$ARCHIVE")"
if grep -Eiq '(^|/).*\.(z64|n64|v64|rom)$|(^|/)oot(-mq)?\.o2r$' \
    <<< "$archive_entries"; then
    echo "Refusing archive containing ROM or ROM-derived inputs: $ARCHIVE" >&2
    exit 1
fi

echo
echo "Generated ROM-free port archive: $ARCHIVE"
shasum -a 256 "$ARCHIVE"
