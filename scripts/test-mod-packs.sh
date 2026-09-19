#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d /tmp/harkinianpad-mod-test.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
# libzip is already a host build dependency. Tests compile the production importer.
read -r -a ZIP_CFLAGS <<< "$(pkg-config --cflags libzip)"
read -r -a ZIP_LIBS <<< "$(pkg-config --libs libzip)"
MPQ_CFLAGS=()
MPQ_LIBS=()
if [ -f "$ROOT/build-host-soh/_deps/stormlib-build/libstorm.a" ]; then
    MPQ_CFLAGS=(-DINCLUDE_MPQ_SUPPORT -I"$ROOT/build-host-soh/_deps/stormlib-src/src")
    MPQ_LIBS=("$ROOT/build-host-soh/_deps/stormlib-build/libstorm.a" -lz -lbz2)
else
    echo "OTR fixture skipped: build host dependencies first"
fi
"${CXX:-c++}" -std=c++20 -Wall -Wextra -Werror \
    "${ZIP_CFLAGS[@]}" ${MPQ_CFLAGS[@]+"${MPQ_CFLAGS[@]}"} -I"$ROOT/sources/Shipwright/soh/soh/Enhancements" \
    "$ROOT/tests/mod_packs_test.cpp" \
    "$ROOT/sources/Shipwright/soh/soh/Enhancements/ModPackImport.cpp" \
    "${ZIP_LIBS[@]}" ${MPQ_LIBS[@]+"${MPQ_LIBS[@]}"} -o "$TEST_DIR/mod_packs_test"
if [ "$#" -eq 1 ]; then set -- "$1" "$TEST_DIR/real-pack"; fi
"$TEST_DIR/mod_packs_test" "$TEST_DIR" "$@"
