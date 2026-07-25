#!/usr/bin/env bash
# Fetch the tracked source trees this project builds from, into ./sources/
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

# These are pinned upstream build inputs. HarkinianPad is the only owned
# project repository; port changes are tracked in HarkinianPad rather than
# pushed to forks of these inputs.
SHIPWRIGHT_REPO="https://github.com/HarbourMasters/Shipwright.git"
LIBULTRASHIP_REPO="https://github.com/Kenix3/libultraship.git"
SHIPWRIGHT_PIN="da4e6dc3321bda48a313b162261156580bc376f4"
LIBULTRASHIP_PIN="2bfbde3a72c119f8073ad762ec6be131dff5df66"
ZAPDTR_PIN="be1c68a79c2d9a463f1b176b5cc32cf9771bfeaf"
OTREXPORTER_PIN="c5465ba0bbd02d80d6ba6beed15d049ab64f5d6d"

LATEST=0
[ "${1:-}" = "--latest" ] && LATEST=1

if [ ! -d "$SRC/Shipwright/.git" ]; then
    echo "==> Cloning pinned upstream Shipwright source…"
    git clone "$SHIPWRIGHT_REPO" "$SRC/Shipwright"
fi

cd "$SRC/Shipwright"
git remote set-url origin "$SHIPWRIGHT_REPO"
# Source inputs are intentionally fetch-only. This prevents an accidental
# `git push` from the disposable checkout.
git config remote.origin.pushurl "disabled://harkinianpad-upstream-input"

if [ "$LATEST" = "1" ]; then
    echo "==> Updating to upstream HEAD…"
    git fetch origin
    git remote set-head origin --auto
    git checkout origin/HEAD --detach
else
    echo "==> Checking out investigated pin ${SHIPWRIGHT_PIN}…"
    git fetch origin "$SHIPWRIGHT_PIN"
    git checkout "$SHIPWRIGHT_PIN" --detach
fi

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
if [ "$LATEST" = "0" ]; then
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
fi

"$ROOT/scripts/apply-source-patches.sh"

echo
echo "Done. Source tree: $SRC/Shipwright"
echo "Shipwright origin: $(git remote get-url origin)"
echo "libultraship origin: $(git -C libultraship remote get-url origin)"
echo "libultraship submodule: ${ACTUAL_LIBULTRASHIP_PIN}"
echo "ZAPDTR submodule: ${ACTUAL_ZAPDTR_PIN}"
echo "OTRExporter submodule: ${ACTUAL_OTREXPORTER_PIN}"
echo "Next: scripts/configure-ios.sh (requires macOS + Xcode)"
