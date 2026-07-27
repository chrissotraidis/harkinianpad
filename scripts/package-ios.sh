#!/usr/bin/env bash
# Audit an iPhoneOS HarkinianPad app and wrap it as an IPA.
#
# This does not sign an unsigned app. Set REQUIRE_SIGNED=1 when producing an
# installable device artifact; that mode requires both a valid code signature
# and an embedded provisioning profile.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build-ios-soh/soh/Release-iphoneos/HarkinianPad.app}"

if [[ "$APP" != /* ]]; then
    APP="$ROOT/$APP"
fi

if [ ! -d "$APP" ] || [ ! -f "$APP/HarkinianPad" ]; then
    echo "HarkinianPad device app not found: $APP" >&2
    exit 1
fi

if ! vtool -show-build "$APP/HarkinianPad" | grep -Eq 'platform +IOS$'; then
    echo "Refusing non-device product: $APP" >&2
    exit 1
fi

for pattern in '*.z64' '*.n64' '*.v64' '*.rom' 'oot*.o2r' '*.otr'; do
    forbidden="$(find "$APP" -type f -iname "$pattern" -print -quit)"
    if [ -n "$forbidden" ]; then
        echo "Refusing app containing ROM or ROM-derived data: $forbidden" >&2
        exit 1
    fi
done

if [ ! -f "$APP/soh.o2r" ]; then
    echo "Required ROM-free port archive is missing: $APP/soh.o2r" >&2
    exit 1
fi

soh_entries="$(unzip -Z1 "$APP/soh.o2r")"
if grep -Eiq '(^|/).*\.(z64|n64|v64|rom)$|(^|/)oot(-mq)?\.o2r$' \
    <<< "$soh_entries"; then
    echo "Refusing soh.o2r containing ROM or ROM-derived data." >&2
    exit 1
fi

signature_state="unsigned"
if codesign --verify --strict "$APP" >/dev/null 2>&1 &&
   [ -f "$APP/embedded.mobileprovision" ]; then
    signature_state="signed"
fi

if [ "$signature_state" = "unsigned" ] &&
   { [ -d "$APP/_CodeSignature" ] || [ -f "$APP/embedded.mobileprovision" ]; }; then
    echo "Refusing unsigned app containing stale signing material: $APP" >&2
    echo "Rebuild with scripts/build-ios.sh --device before packaging." >&2
    exit 1
fi

if [ "${REQUIRE_SIGNED:-0}" = "1" ] && [ "$signature_state" != "signed" ]; then
    echo "REQUIRE_SIGNED=1, but the app lacks a valid device signature/profile." >&2
    exit 1
fi

version="$(/usr/libexec/PlistBuddy \
    -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")"
build_number="$(/usr/libexec/PlistBuddy \
    -c 'Print :CFBundleVersion' "$APP/Info.plist")"
bundle_id="$(/usr/libexec/PlistBuddy \
    -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
   [[ ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
    echo "Refusing app with invalid release version: $version ($build_number)" >&2
    exit 1
fi
output="${2:-$ROOT/artifacts/HarkinianPad-${version}-preview.${build_number}-${signature_state}.ipa}"
if [[ "$output" != /* ]]; then
    output="$ROOT/$output"
fi

mkdir -p "$(dirname "$output")"
package_root="$(mktemp -d /tmp/harkinianpad-package.XXXXXX)"
trap 'rm -rf "$package_root"' EXIT
mkdir "$package_root/Payload"
ditto "$APP" "$package_root/Payload/HarkinianPad.app"
ditto -c -k --norsrc --keepParent "$package_root/Payload" "$output"

ipa_entries="$(unzip -Z1 "$output")"
if ! grep -Fxq 'Payload/HarkinianPad.app/HarkinianPad' \
    <<< "$ipa_entries"; then
    echo "IPA payload verification failed: $output" >&2
    exit 1
fi

if grep -Eiq '\.(z64|n64|v64|rom)$|Payload/.*/oot(-mq)?\.o2r$|\.otr$' \
    <<< "$ipa_entries"; then
    echo "Refusing IPA containing ROM or ROM-derived data: $output" >&2
    exit 1
fi

echo "Packaged ${signature_state} HarkinianPad ${version} (${build_number})"
echo "Bundle identifier: $bundle_id"
echo "IPA: $output"
shasum -a 256 "$output"
if [ "$signature_state" != "signed" ]; then
    echo "This proof artifact is not installable on a standard device until signed."
fi
