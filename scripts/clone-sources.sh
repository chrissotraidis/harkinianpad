#!/usr/bin/env bash
# Fetch the tracked source trees this project builds from, into ./sources/
# (git-ignored). Pins match the investigation in docs/ (see the revision
# table at the top of docs/ios-feasibility-and-implementation-plan.md).
#
# Usage:
#   scripts/clone-sources.sh            # clone Shipwright + submodules
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/sources"
mkdir -p "$SRC"

# The lock is the single source of truth for upstream identities.
read_pin() {
    python3 - "$ROOT/sources.lock.json" "$1" "$2" <<'PYCODE'
import json, sys
components = json.load(open(sys.argv[1]))['components']
print(next(c for c in components if c['name'] == sys.argv[2])[sys.argv[3]])
PYCODE
}
SHIPWRIGHT_REPO="$(read_pin Shipwright url)"
LIBULTRASHIP_REPO="$(read_pin libultraship url)"
SHIPWRIGHT_PIN="$(read_pin Shipwright commit)"
LIBULTRASHIP_PIN="$(read_pin libultraship commit)"
ZAPDTR_PIN="$(read_pin ZAPDTR commit)"
OTREXPORTER_PIN="$(read_pin OTRExporter commit)"

if [ "$#" -ne 0 ]; then
    echo "Only locked source preparation is supported. Research upstream upgrades in a separate checkout." >&2
    exit 2
fi

# Never checkout, update submodules or overwrite a pre-existing prepared tree.
if [ -e "$SRC/Shipwright" ]; then
    if "$ROOT/scripts/verify-sources.py" >/dev/null 2>&1; then
        echo "Verified existing prepared sources; no files changed."
        exit 0
    fi
    "$ROOT/scripts/verify-sources.py" --pristine >/dev/null
    "$ROOT/scripts/apply-source-patches.sh"
    exit 0
fi

if [ ! -d "$SRC/Shipwright/.git" ]; then
    echo "==> Cloning pinned upstream Shipwright source…"
    git clone "$SHIPWRIGHT_REPO" "$SRC/Shipwright"
fi

cd "$SRC/Shipwright"
git remote set-url origin "$SHIPWRIGHT_REPO"
# Source inputs are intentionally fetch-only. This prevents an accidental
# `git push` from the disposable checkout.
git config remote.origin.pushurl "disabled://harkinianpad-upstream-input"

echo "==> Checking out locked Shipwright revision ${SHIPWRIGHT_PIN}…"
git fetch origin "$SHIPWRIGHT_PIN"
git checkout "$SHIPWRIGHT_PIN" --detach

# Keep the submodule on Shipwright's exact gitlink while making the upstream
# input explicit in the local checkout.
git config submodule.libultraship.url "$LIBULTRASHIP_REPO"
git submodule update --init --recursive
git -C libultraship remote set-url origin "$LIBULTRASHIP_REPO"

for upstream_input in libultraship ZAPDTR OTRExporter; do
    git -C "$upstream_input" config remote.origin.pushurl \
        "disabled://harkinianpad-upstream-input"
done

ACTUAL_LIBULTRASHIP_PIN="$(git -C libultraship rev-parse HEAD)"
ACTUAL_ZAPDTR_PIN="$(git -C ZAPDTR rev-parse HEAD)"
ACTUAL_OTREXPORTER_PIN="$(git -C OTRExporter rev-parse HEAD)"
for pin_check in \
    "libultraship:$ACTUAL_LIBULTRASHIP_PIN:$LIBULTRASHIP_PIN" \
    "ZAPDTR:$ACTUAL_ZAPDTR_PIN:$ZAPDTR_PIN" \
    "OTRExporter:$ACTUAL_OTREXPORTER_PIN:$OTREXPORTER_PIN"; do
    IFS=: read -r input_name actual_pin expected_pin <<< "$pin_check"
    if [ "$actual_pin" != "$expected_pin" ]; then
        echo "Unexpected $input_name revision: $actual_pin" >&2
        echo "Expected: $expected_pin" >&2
        exit 1
    fi
done

"$ROOT/scripts/apply-source-patches.sh"

echo
echo "Done. Source tree: $SRC/Shipwright"
echo "Shipwright origin: $(git remote get-url origin)"
echo "libultraship origin: $(git -C libultraship remote get-url origin)"
echo "libultraship submodule: ${ACTUAL_LIBULTRASHIP_PIN}"
echo "ZAPDTR submodule: ${ACTUAL_ZAPDTR_PIN}"
echo "OTRExporter submodule: ${ACTUAL_OTREXPORTER_PIN}"
echo "Next: scripts/configure-ios.sh (requires macOS + Xcode)"
