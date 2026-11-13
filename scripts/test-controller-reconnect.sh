#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLOTS_SOURCE="$ROOT/sources/Shipwright/libultraship/src/ship/controller/physicaldevice/ControllerSlotAssignments.cpp"

if [ ! -f "$SLOTS_SOURCE" ]; then
    "$ROOT/scripts/clone-sources.sh"
fi

test_dir="$(mktemp -d /tmp/harkinianpad-controller-test.XXXXXX)"
trap 'rm -rf "$test_dir"' EXIT

"${CXX:-c++}" -std=c++20 -Wall -Wextra -Werror \
    -I"$ROOT/sources/Shipwright/libultraship/include" \
    "$ROOT/tests/controller_slot_assignments_test.cpp" \
    "$SLOTS_SOURCE" \
    -o "$test_dir/controller_slot_assignments_test"

"$test_dir/controller_slot_assignments_test"

"${CXX:-c++}" -std=c++20 -Wall -Wextra -Werror \
    -I"$ROOT/sources/Shipwright/libultraship/include" \
    -I"$ROOT/sources/Shipwright/soh/ios" \
    "$ROOT/tests/touch_visibility_test.cpp" \
    "$SLOTS_SOURCE" \
    -o "$test_dir/touch_visibility_test"

"$test_dir/touch_visibility_test"
