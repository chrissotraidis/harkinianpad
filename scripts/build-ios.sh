#!/usr/bin/env bash
# Reproduce HarkinianPad from pinned upstream inputs.
#
# The build is ROM-free. A legally acquired supported ROM may be kept under
# ignored ref/ for later import into the installed app, but this script never
# reads or packages it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:---device}"
PREFIX_MAP="-ffile-prefix-map=$ROOT=."

case "$MODE" in
    --device|--simulator)
        ;;
    *)
        echo "Usage: scripts/build-ios.sh [--device|--simulator]" >&2
        exit 2
        ;;
esac

stage=prepare
started=$SECONDS
trap 'result=$?; printf "[HarkinianPad build] stage=%s result=%s elapsed_seconds=%s\n" "$stage" "$result" "$((SECONDS-started))" >&2' EXIT
log_stage() {
    stage="$1"
    printf '[HarkinianPad build] utc=%s stage=%s elapsed_seconds=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$stage" "$((SECONDS-started))" >&2
}
log_stage prepare
"$ROOT/scripts/clone-sources.sh"
"$ROOT/scripts/verify-sources.py"
log_stage port-archive
"$ROOT/scripts/generate-port-archive.sh"

if find "$ROOT/ref" -maxdepth 1 -type f \
    \( -iname '*.z64' -o -iname '*.n64' -o -iname '*.v64' \) \
    -print -quit | grep -q .; then
    echo "ROM detected under ignored ref/; it remains local and is not part of the build."
fi

if [ "$MODE" = "--simulator" ]; then
    log_stage configure-simulator
    IOS_PLATFORM=SIMULATORARM64 "$ROOT/scripts/configure-ios.sh" --soh
    log_stage compile-simulator
    cmake --build "$ROOT/build-ios-soh-sim" --target soh --config Release -- \
        "OTHER_CFLAGS=\$(inherited) $PREFIX_MAP" \
        "OTHER_CPLUSPLUSFLAGS=\$(inherited) $PREFIX_MAP"
    log_stage provenance
    "$ROOT/scripts/write-build-provenance.py" "$ROOT/build-ios-soh-sim/soh/Release-iphonesimulator/HarkinianPad.app"
    log_stage complete
    echo
    echo "Simulator app:"
    echo "  $ROOT/build-ios-soh-sim/soh/Release-iphonesimulator/HarkinianPad.app"
    exit 0
fi

log_stage configure-device
"$ROOT/scripts/configure-ios.sh" --soh

# A previous signed build can leave a profile and _CodeSignature inside the
# product directory. Remove only the generated app before an unsigned or
# differently signed rebuild so no stale signing material survives.
rm -rf "$ROOT/build-ios-soh/soh/Release-iphoneos/HarkinianPad.app"

set -- cmake --build "$ROOT/build-ios-soh" --target soh --config Release -- \
    -destination generic/platform=iOS \
    "OTHER_CFLAGS=\$(inherited) $PREFIX_MAP" \
    "OTHER_CPLUSPLUSFLAGS=\$(inherited) $PREFIX_MAP"
if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
    set -- "$@" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
fi
log_stage compile-device
"$@"

# The report is a sidecar so signed bundles are never modified after signing.
log_stage provenance
"$ROOT/scripts/write-build-provenance.py" "$ROOT/build-ios-soh/soh/Release-iphoneos/HarkinianPad.app"
log_stage complete

echo
echo "Device app:"
echo "  $ROOT/build-ios-soh/soh/Release-iphoneos/HarkinianPad.app"
if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
    echo "  unsigned compile proof; set DEVELOPMENT_TEAM and BUNDLE_ID to sign"
else
    echo "  signing requested for team $DEVELOPMENT_TEAM"
fi
