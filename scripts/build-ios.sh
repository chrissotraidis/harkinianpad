#!/usr/bin/env bash
# Reproduce HarkinianPad from pinned upstream inputs.
#
# The build is ROM-free. A legally acquired supported ROM may be kept under
# ignored ref/ for later import into the installed app, but this script never
# reads or packages it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:---device}"

case "$MODE" in
    --device|--simulator)
        ;;
    *)
        echo "Usage: scripts/build-ios.sh [--device|--simulator]" >&2
        exit 2
        ;;
esac

"$ROOT/scripts/clone-sources.sh"
"$ROOT/scripts/generate-port-archive.sh"

if find "$ROOT/ref" -maxdepth 1 -type f \
    \( -iname '*.z64' -o -iname '*.n64' -o -iname '*.v64' \) \
    -print -quit | grep -q .; then
    echo "ROM detected under ignored ref/; it remains local and is not part of the build."
fi

if [ "$MODE" = "--simulator" ]; then
    IOS_PLATFORM=SIMULATORARM64 "$ROOT/scripts/configure-ios.sh" --soh
    cmake --build "$ROOT/build-ios-soh-sim" --target soh --config Release
    echo
    echo "Simulator app:"
    echo "  $ROOT/build-ios-soh-sim/soh/Release-iphonesimulator/HarkinianPad.app"
    exit 0
fi

"$ROOT/scripts/configure-ios.sh" --soh

set -- cmake --build "$ROOT/build-ios-soh" --target soh --config Release -- \
    -destination generic/platform=iOS
if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
    set -- "$@" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
fi
"$@"

echo
echo "Device app:"
echo "  $ROOT/build-ios-soh/soh/Release-iphoneos/HarkinianPad.app"
if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
    echo "  unsigned compile proof; set DEVELOPMENT_TEAM and BUNDLE_ID to sign"
else
    echo "  signing requested for team $DEVELOPMENT_TEAM"
fi
