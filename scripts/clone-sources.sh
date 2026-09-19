#!/usr/bin/env bash
# Obtain immutable maintained source; never rewrite existing source files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$#" -ne 0 ]; then
    echo "Only locked sources are supported; update pins in a reviewed change." >&2
    exit 2
fi
if [ -d "$ROOT/sources/Shipwright" ] && [ -n "$(ls -A "$ROOT/sources/Shipwright")" ]; then
    "$ROOT/scripts/verify-sources.py"
    echo "Verified existing sources; no files changed."
else
    git -C "$ROOT" submodule update --init --recursive -- sources/Shipwright
    "$ROOT/scripts/verify-sources.py"
fi
