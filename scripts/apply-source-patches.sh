#!/usr/bin/env bash
# Apply HarkinianPad's maintained iOS changes to pinned upstream source inputs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHIPWRIGHT="$ROOT/sources/Shipwright"

if ! git -C "$SHIPWRIGHT" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
   ! git -C "$SHIPWRIGHT/libultraship" rev-parse \
       --is-inside-work-tree >/dev/null 2>&1 ||
   ! git -C "$SHIPWRIGHT/ZAPDTR" rev-parse \
       --is-inside-work-tree >/dev/null 2>&1; then
    echo "Missing source inputs. Run scripts/clone-sources.sh first." >&2
    exit 1
fi

apply_patch() {
    local tree="$1"
    local patch="$2"

    if [[ "${3:-}" == "ignore-space-change" ]]; then
        set -- --ignore-space-change
    else
        set --
    fi

    if git -C "$tree" apply "$@" --check "$patch" 2>/dev/null; then
        git -C "$tree" apply "$@" "$patch"
        echo "Applied $(basename "$patch")"
    elif git -C "$tree" apply "$@" --reverse --check "$patch" 2>/dev/null; then
        echo "Already applied: $(basename "$patch")"
    else
        echo "Patch does not apply cleanly: $patch" >&2
        exit 1
    fi
}

apply_patch "$SHIPWRIGHT/libultraship" \
    "$ROOT/patches/libultraship-ios.patch"
apply_patch "$SHIPWRIGHT/ZAPDTR" "$ROOT/patches/zapdtr-ios.patch" \
    ignore-space-change

# The focused first-run patch layers on the main Shipwright patch. Detect the
# final state first so rerunning this script stays idempotent.
if git -C "$SHIPWRIGHT" apply --reverse --check \
    "$ROOT/patches/shipwright-ios-first-run.patch" 2>/dev/null; then
    echo "Already applied: shipwright-ios.patch"
    echo "Already applied: shipwright-ios-first-run.patch"
else
    apply_patch "$SHIPWRIGHT" "$ROOT/patches/shipwright-ios.patch"
    apply_patch "$SHIPWRIGHT" "$ROOT/patches/shipwright-ios-first-run.patch"
fi
