#!/usr/bin/env bash
# Compatibility entry point. Production sources are already maintained commits.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Patch replay is retired. Verifying immutable maintained sources."
exec "$ROOT/scripts/verify-sources.py" "$@"
