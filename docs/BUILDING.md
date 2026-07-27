# Building HarkinianPad for iOS and iPadOS

These instructions build only `chrissotraidis/harkinianpad`. Shipwright,
libultraship, ZAPDTR, and OTRExporter are pinned, disposable upstream source
inputs; do not push HarkinianPad changes to forks of them.

## Requirements

- macOS with Xcode and its command-line tools
- [Homebrew](https://brew.sh)
- a legally acquired supported Ocarina of Time ROM for first-run extraction
- for physical-device installation: an Apple ID configured in Xcode, a unique
  bundle identifier, and a registered device

ROMs and ROM-derived archives belong only in ignored local storage such as
`ref/` or the app's Files-visible Documents folder. Never add them to Git or
an app/IPA bundle.

Install the host tools and libraries used to generate Shipwright's ROM-free
port archive:

```sh
brew install cmake ninja pkgconf sdl2 glew nlohmann-json libpng libzip \
  tinyxml2 libogg libvorbis opus opusfile
```

## Clean-machine build

On another Mac, clone only HarkinianPad and optionally place one legally
acquired supported ROM under ignored `ref/`:

```sh
git clone https://github.com/chrissotraidis/harkinianpad.git
cd harkinianpad
cp "/path/to/your-supported-oot-rom.v64" ref/

scripts/build-ios.sh --simulator
```

The ROM is deliberately not a compile input. The wrapper fetches and verifies
every pinned source revision, disables upstream push URLs, applies the tracked
patches, generates the ROM-free port archive, and builds the complete app.
Keeping the ROM in `ref/` makes it available for later local import while
proving that it cannot leak into source control or the built product.

Use `scripts/build-ios.sh --device` for the unsigned device compile proof.
The individual commands below remain available for diagnosis and CI parity.

## Reproduce the source and app build

From the HarkinianPad repository root:

```sh
scripts/clone-sources.sh
scripts/generate-port-archive.sh
scripts/configure-ios.sh --soh
cmake --build build-ios-soh --target soh --config Release -- \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -destination generic/platform=iOS
```

The unsigned device product is
`build-ios-soh/soh/Release-iphoneos/HarkinianPad.app`. It is a compile and
package-safety proof, not an installable standard-device build.

To build the arm64 Simulator product:

```sh
IOS_PLATFORM=SIMULATORARM64 scripts/configure-ios.sh --soh
cmake --build build-ios-soh-sim --target soh --config Release
```

Install that `.app` through Xcode or `simctl`. On first launch, use the
in-app instructions to place your ROM in
`On My iPhone > HarkinianPad` or `On My iPad > HarkinianPad`, then choose
**Rescan**. Leave HarkinianPad open while using Files. The generated
`oot.o2r` stays in the app container and is not part of the build.

## Sign for a physical device

First find the 10-character development-team identifier shown for your Apple
ID in Xcode. Choose a bundle identifier you control, then regenerate and build:

```sh
DEVELOPMENT_TEAM=ABCDE12345 \
BUNDLE_ID=com.yourname.harkinianpad \
scripts/configure-ios.sh --soh

cmake --build build-ios-soh --target soh --config Release -- \
  -destination generic/platform=iOS
```

If automatic signing needs to register the device or create a profile, open
`build-ios-soh/Ship.xcodeproj` in Xcode, select the `soh` scheme and your
device, confirm the team under Signing & Capabilities, and build once. A free
personal team is suitable for local testing but has shorter provisioning
validity; paid-team distribution and TestFlight have separate Apple
requirements.

Before installation or sharing, package and audit the built app:

```sh
REQUIRE_SIGNED=1 scripts/package-ios.sh
```

The command refuses Simulator products, missing provisioning, ROMs,
ROM-derived `oot*.o2r`/`.otr` data, or a `soh.o2r` containing prohibited
inputs. It writes an ignored IPA under `artifacts/` and prints its SHA-256.
Without `REQUIRE_SIGNED=1`, it may create a clearly labeled unsigned IPA for
reproducibility testing only.

Install the signed `.app` from Xcode's Devices and Simulators window, or the
signed IPA with a compatible personal-signing/sideload tool. TestFlight,
AltStore PAL, and SideStore are distinct distribution paths with their own
account, region, review, and provisioning constraints; a successful local
build does not prove any of them.

## Touch and controller playtest

HarkinianPad starts with a lower-half, low-grip touch layout. The left rail has
L/Z, a separate four-button D-pad, and a low control stick. The right rail has
Start/R, an A/B/Z cluster, a menu button, and a separate low four-button
C diamond. The duplicated Z control keeps the trigger reachable from either
grip. Empty overlay space passes through to the game and menus. Open the menu
with **•••**; the gameplay overlay disappears while the menu is visible and
returns when the menu closes. Turn it off or back on entirely under
**Settings > Controls > Touch Controls**.

The basic touch bridge reuses the existing bindings:

| Touch control | Binding |
|---|---|
| Stick | W/A/S/D, including diagonals |
| D-pad | T/G/F/H |
| A / B | X / C |
| L / Z (either) / R | E / Z / R |
| Start | Space or Return |
| C buttons | Arrow keys |
| Menu | Escape |

The touch stick is an eight-way testing control, not a replacement for the
analog precision of a physical controller. On a physical iPhone or iPad, pair
an MFi, Xbox, PlayStation, or other iOS-supported extended-gamepad controller
in Settings before launching the app. For a Simulator-only check, connect the
controller to the Mac and choose **I/O > Input > Send Game Controller to
Device** in Simulator.

For keyboard and pointing-device testing, the default mappings are:

| Device input | N64 action |
|---|---|
| W/A/S/D | Control stick |
| X / C / Z | A / B / Z |
| Space or Return | Start |
| Arrow keys | C buttons |
| Primary / secondary / middle click | A / B / Z |

On an installation that already wrote an older controller configuration,
expand Keyboard or Mouse under **Settings > Controls** and choose
**Set Defaults** once. Trackpad/mouse input complements the keyboard; it does
not replace movement input.

At the title screen, test the touch layout and then the controller separately.
Confirm that:

1. Start opens file select, A accepts, B cancels, and the stick navigates.
   Confirm the D-pad and C buttons emit their mapped inputs in gameplay or the
   input viewer.
2. Disabling **Touch Controls** removes the overlay immediately; enabling it
   restores the overlay without restarting.
3. Opening the menu hides every gameplay control, and closing it restores the
   overlay only when **Touch Controls** is enabled.
4. A save can be created or selected and Link can be controlled in active
   gameplay for at least ten minutes.
5. Disconnecting and reconnecting the controller does not crash the app and
   restores control without losing the current save.
6. Rumble and motion input are recorded as supported, unsupported, or not
   exposed for the exact controller model; do not infer either capability
   from the extended-gamepad declaration.

Record the controller model, connection type, device model, OS version, and
each observed result in [`remaining-work.md`](remaining-work.md). A controller
forwarded through Simulator is useful diagnostic evidence, but only the
physical-device replay closes the M4 acceptance gate.

Keyboard and pointing-device input remain diagnostic conveniences rather than
substitutes for the physical-controller acceptance test.

## Required device acceptance checks

Do not call the port complete until the physical-device gates in
[`remaining-work.md`](remaining-work.md) pass:

1. Import and extract the ROM entirely through Files on the device.
2. Play with an MFi/Bluetooth controller and check navigation, gameplay,
   reconnect, rumble, and gyro where supported.
3. Repeatedly background/foreground active gameplay, then verify settings and
   an immediate pre-background save after termination and cold relaunch.
4. Exercise speaker, headphones/Bluetooth, and a real audio interruption.
5. Re-run `REQUIRE_SIGNED=1 scripts/package-ios.sh`, install the result, and
   record the bundle ID, version, device/OS, archive hash, and observed result.
