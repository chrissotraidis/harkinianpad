#include "HarkinianPadTouchVisibility.h"
#include "ship/controller/physicaldevice/ControllerSlotAssignments.h"

#include <cstdlib>
#include <iostream>
#include <string>
#include <unordered_map>

namespace {
using Assignments = Ship::ControllerSlotAssignments;
using HarkinianPad::GamepadProfile;
using HarkinianPad::TouchPreferences;

constexpr GamepadProfile kFullGamepad = { true, true, true };
constexpr GamepadProfile kMenuOnlyRemote = { false, false, true };

[[noreturn]] void Fail(const std::string& message) {
    std::cerr << "touch visibility regression failed: " << message << '\n';
    std::exit(1);
}

void Expect(bool condition, const std::string& message) {
    if (!condition) {
        Fail(message);
    }
}

// Mirrors the game's per-frame query: only the gamepad libultraship assigns
// to player 1 can hide player 1's touch controller.
bool TouchVisible(const TouchPreferences& preferences, const Assignments& assignments,
                  const std::unordered_map<int32_t, GamepadProfile>& profiles) {
    bool playerOneReady = false;
    if (auto instanceId = assignments.GetInstanceId(0)) {
        auto profile = profiles.find(*instanceId);
        playerOneReady = profile != profiles.end() && HarkinianPad::IsGameplayGamepad(profile->second);
    }
    return HarkinianPad::TouchGameplayControlsVisible(preferences, playerOneReady);
}
} // namespace

int main() {
    const std::unordered_map<int32_t, GamepadProfile> profiles = {
        { 11, kFullGamepad }, { 12, kFullGamepad }, { 21, kFullGamepad }, { 31, kMenuOnlyRemote },
    };
    TouchPreferences preferences; // no saved choice yet
    Assignments assignments;

    Expect(TouchVisible(preferences, assignments, profiles), "touch hidden with no controller");

    // A controller connected before launch is found by the first reconcile.
    assignments.Reconcile({ { 11, "pad-a" } });
    Expect(!TouchVisible(preferences, assignments, profiles), "pre-launch controller did not auto-hide touch");

    // Disconnect, then reconnect during play with a new SDL instance ID.
    assignments.Reconcile({});
    Expect(TouchVisible(preferences, assignments, profiles), "touch did not return after disconnect");
    assignments.Reconcile({ { 12, "pad-a" } });
    Expect(!TouchVisible(preferences, assignments, profiles), "reconnected controller did not auto-hide touch");

    // With two controllers, losing player 2 keeps player 1's controller.
    assignments.Reconcile({ { 12, "pad-a" }, { 21, "pad-b" } });
    assignments.Reconcile({ { 12, "pad-a" } });
    Expect(!TouchVisible(preferences, assignments, profiles), "removing player 2 reported player 1 disconnected");

    // A controller that belongs to player 2 does not hide player 1's touch.
    assignments.Reconcile({ { 12, "pad-a" }, { 21, "pad-b" } });
    assignments.Reconcile({ { 21, "pad-b" } });
    Expect(assignments.GetSlot(21) == 1, "remaining controller changed player slot");
    Expect(TouchVisible(preferences, assignments, profiles), "player 2 controller hid player 1 touch");

    // A menu-only profile on player 1 cannot play, so touch stays.
    assignments.Reconcile({});
    assignments.Reconcile({ { 31, "remote" } });
    Expect(assignments.GetSlot(31) == 0, "remote did not take player 1");
    Expect(TouchVisible(preferences, assignments, profiles), "menu-only profile hid gameplay touch");

    // Preference changes apply to the current controller state at once.
    assignments.Reconcile({});
    assignments.Reconcile({ { 11, "pad-a" } });
    preferences.autoHideWithController = false;
    Expect(TouchVisible(preferences, assignments, profiles), "auto-hide off did not restore touch");
    preferences.autoHideWithController = true;
    Expect(!TouchVisible(preferences, assignments, profiles), "auto-hide on ignored connected controller");

    // Show recovers a manual hide with the controller still connected, turns
    // auto-hide off, and leaves player assignments alone.
    preferences.touchControls = false;
    Expect(!TouchVisible(preferences, assignments, profiles), "manual hide was not respected");
    preferences = HarkinianPad::ShowTouchControls(preferences);
    Expect(preferences.touchControls && !preferences.autoHideWithController, "Show did not reset preferences");
    Expect(TouchVisible(preferences, assignments, profiles), "Show did not restore touch with controller");
    Expect(assignments.GetSlot(11) == 0, "Show changed player assignment");
    assignments.Reconcile({});
    assignments.Reconcile({ { 12, "pad-a" } });
    Expect(TouchVisible(preferences, assignments, profiles), "reconnect re-hid touch after Show");
    preferences.autoHideWithController = true;
    Expect(!TouchVisible(preferences, assignments, profiles), "re-enabled auto-hide did not hide touch");

    // Releasing player 1's controller in settings brings touch back.
    Expect(assignments.Unassign(12, 0), "settings could not release player 1 controller");
    Expect(TouchVisible(preferences, assignments, profiles), "released controller still hid touch");

    std::cout << "touch visibility regression passed\n";
    return 0;
}
