# HarkinianPad

<p align="center">
  <strong>Ocarina of Time via Ship of Harkinian, rebuilt for iPhone and iPad.</strong><br>
  Native Metal rendering, touch controls, Files-based setup, and support for
  keyboards, pointing devices, and iOS game controllers.
</p>

<p align="center">
  <img alt="iOS 14+" src="https://img.shields.io/badge/iOS%20%2F%20iPadOS-14%2B-0A84FF?logo=apple">
  <img alt="Metal renderer" src="https://img.shields.io/badge/renderer-Metal-5E5CE6">
  <img alt="Physical iPad tested" src="https://img.shields.io/badge/physical%20iPad-tested-30D158">
  <img alt="Downloadable IPA coming soon" src="https://img.shields.io/badge/IPA-coming%20soon-FF9F0A">
  <img alt="ROM not included" src="https://img.shields.io/badge/game%20data-not%20included-FF453A">
</p>

![HarkinianPad running Ocarina of Time on a physical iPad with its touch controller](docs/readme/harkinianpad-gameplay.jpg)

HarkinianPad packages the full
[Ship of Harkinian](https://github.com/HarbourMasters/Shipwright) source port
as a native iOS/iPadOS app. It renders through Metal, imports a user-provided
supported Ocarina of Time ROM through Files, and includes a landscape touch
controller that can be hidden whenever a physical controller is connected.

This repository contains the mobile integration and reproducible build
scripts. It does **not** contain Ocarina of Time, a ROM, or a playable
ROM-derived archive.

## Install status

| Option | Status | What to do |
|---|---|---|
| Downloadable `.ipa` | **Coming soon** | No official download is available yet. It will still require a compatible personal-signing or sideload workflow. |
| Local iPad build | **Available now** | Build and sign with your Apple development team using the instructions below. |
| Simulator | **Available now** | Best for development and UI testing; it is not a substitute for physical-device testing. |
| App Store / TestFlight | **Not announced** | No listing or public TestFlight currently exists. |

The current development build has been signed, installed, and played on a
12.9-inch iPad Pro (6th generation) running iPadOS 26.5.2. Files import,
on-device archive loading, touch gameplay, save loading, the settings menu,
and in-place app updates have all been exercised on that hardware.

Two gates remain intentionally explicit:

- SDL reports a working audio device, but audible physical-device output is
  still being investigated.
- The iOS controller path is present, but the physical controller,
  disconnect/reconnect, rumble, and motion matrix has not been completed.

## Get started

You need:

- a Mac with Xcode and its command-line tools;
- [Homebrew](https://brew.sh);
- an Apple ID configured in Xcode for physical-device signing; and
- your own legally acquired, supported Ocarina of Time ROM.

Install the build dependencies:

```sh
brew install cmake ninja pkgconf sdl2 glew nlohmann-json libpng libzip \
  tinyxml2 libogg libvorbis opus opusfile
```

Clone and build:

```sh
git clone https://github.com/chrissotraidis/harkinianpad.git
cd harkinianpad

# Simulator
scripts/build-ios.sh --simulator

# Physical iPhone or iPad
DEVELOPMENT_TEAM=ABCDE12345 \
BUNDLE_ID=com.yourname.harkinianpad \
scripts/build-ios.sh --device
```

Replace `ABCDE12345` with the 10-character team identifier shown in Xcode and
use a bundle identifier that belongs to you. The device app is written to:

```text
build-ios-soh/soh/Release-iphoneos/HarkinianPad.app
```

If Xcode needs to register the device or create a provisioning profile, open
`build-ios-soh/Ship.xcodeproj`, select the `soh` target and your device, then
choose your team under **Signing & Capabilities**.

See [`docs/BUILDING.md`](docs/BUILDING.md) for the complete Simulator,
signing, installation, controller, and package-audit workflow.

## First launch

HarkinianPad never downloads or bundles game data.

1. Launch HarkinianPad once so iOS creates its Files-visible folder.
2. Open **Files → On My iPad → HarkinianPad**.
3. Move your supported Ocarina of Time ROM into that folder.
4. Return to HarkinianPad and select **Rescan**.
5. Leave the app open while it creates the local `oot.o2r` archive.
6. Press the on-screen Start button or Start on a connected controller.

The original ROM and generated archive stay inside the app container. They
are ignored by Git and rejected by the repository's package audit.

## Touch controls

The controller is arranged for a landscape iPad held at both edges:

- **Left:** L and Z, a compact D-pad, and the control stick.
- **Right:** Start and R, the A/B/Z face cluster, and the C-button diamond.
- **Menu:** the small `•••` button remains available even when gameplay touch
  controls are disabled.
- **Toggle:** use **Settings → Controls → Touch Controls** to hide or restore
  the gameplay overlay.
- **Safety:** Reset requires confirmation instead of restarting immediately.

Opening the menu hides the gameplay controls so the settings interface remains
usable. Closing it restores the controls only when Touch Controls is enabled.

| Touch control | Shipwright binding |
|---|---|
| Control stick | W/A/S/D, including diagonals |
| D-pad | T/G/F/H |
| A / B | X / C |
| L / Z / R | E / Z / R |
| Start | Space or Return |
| C buttons | Arrow keys |
| Menu | Escape |

The touch stick is currently an eight-way control. A physical controller
remains the preferred option for full analog precision.

## Current screenshots

<table>
  <tr>
    <td width="50%">
      <img src="docs/readme/simulator-file-select.jpg" alt="Current HarkinianPad file-select screen in iPad Simulator">
    </td>
    <td width="50%">
      <img src="docs/readme/simulator-settings.jpg" alt="Current HarkinianPad settings interface in iPad Simulator">
    </td>
  </tr>
  <tr>
    <td align="center"><strong>Ready to play</strong><br>Every N64 input is available without a separate controller.</td>
    <td align="center"><strong>Adjust while running</strong><br>Touch controls can be toggled from Settings → Controls.</td>
  </tr>
</table>

The hero image is from the physical iPad build. The two interface captures are
from the current iPad Simulator build. All game data used for these captures
was supplied locally and is not part of this repository.

## What works

| Area | Current result |
|---|---|
| Native app | Complete Shipwright app builds for arm64 iOS/iPadOS 14+ |
| Rendering | Metal rendering works in Simulator and on physical iPad |
| Game setup | Files-visible ROM import and local `oot.o2r` loading work |
| Touch | Stick, D-pad, A/B/Z, C buttons, shoulders, Start, and persistent menu access |
| Saves | File creation/loading and in-place app updates preserving Documents data work |
| Input options | Touch, keyboard, mouse/trackpad, and SDL's iOS controller path are included |
| Packaging | ROM/game-data exclusions and signed-package checks are built into the scripts |

For detailed engineering evidence and remaining hardware checks, see
[`docs/remaining-work.md`](docs/remaining-work.md).

## Supported game

| Game | Engine | Status |
|---|---|---|
| **The Legend of Zelda: Ocarina of Time** | [Ship of Harkinian](https://github.com/HarbourMasters/Shipwright) | Supported |
| **The Legend of Zelda: Majora's Mask** | [2 Ship 2 Harkinian](https://github.com/HarbourMasters/2ship2harkinian) | Not supported by this app; it requires a separate port |

HarkinianPad is a native source-port integration, not a general Nintendo 64
emulator. A Majora's Mask ROM cannot be substituted for Ocarina of Time data.

## Reproducible and ROM-free

```mermaid
flowchart LR
    A["HarkinianPad scripts"] --> B["Pinned upstream source"]
    B --> C["Maintained iOS patches"]
    C --> D["Signed iOS app"]
    E["Your supported ROM"] --> F["Files-visible app folder"]
    D --> G["Local extraction"]
    F --> G
    G --> H["Local oot.o2r and gameplay"]
```

The compile never reads your ROM. `scripts/build-ios.sh` fetches exact upstream
revisions, disables their push URLs, applies the maintained patches, generates
Shipwright's ROM-free `soh.o2r`, and builds the app. Your ROM is introduced
only after installation.

Before installing or sharing a local device build, run:

```sh
REQUIRE_SIGNED=1 scripts/package-ios.sh
```

The audit rejects Simulator products, missing signing/provisioning, original
ROMs, ROM-derived `oot*.o2r`/`.otr` files, and prohibited game data in the app
package.

## Frequently asked questions

<details>
<summary><strong>Where is the IPA?</strong></summary>

A downloadable IPA is coming soon. The current repository supports local
Xcode builds, but no official public binary is available yet. An IPA does not
remove Apple's signing requirements; installation will still need a compatible
personal-signing or sideload workflow.
</details>

<details>
<summary><strong>Does this repository include Ocarina of Time?</strong></summary>

No. You must provide your own legally acquired supported ROM. Do not open
issues requesting game data or download links.
</details>

<details>
<summary><strong>Why can I see the game but not hear it?</strong></summary>

The SDL audio backend initializes on iPad, but audible physical-device output
is still an active investigation. The README will not claim working speaker,
headphone, or Bluetooth audio until those paths are physically verified.
</details>

<details>
<summary><strong>Can I hide touch controls and get them back later?</strong></summary>

Yes. The persistent `•••` button keeps the menu reachable. Open
**Settings → Controls** and toggle **Touch Controls**.
</details>

<details>
<summary><strong>Does it support controllers?</strong></summary>

The existing Shipwright SDL controller mappings are compiled into the app for
iOS-compatible controllers. Physical gameplay, reconnect, rumble, and motion
support still require model-specific verification.
</details>

<details>
<summary><strong>Is this an App Store or TestFlight release?</strong></summary>

No. A downloadable IPA is planned first. App Store, TestFlight, AltStore PAL,
and SideStore distribution each have separate signing, review, account, and
regional requirements.
</details>

<details>
<summary><strong>What is the licensing status?</strong></summary>

Each upstream component retains its own license and copyright. Libultraship,
ZAPDTR, OTRExporter, SDL, and their dependencies carry their respective
licenses. The pinned Shipwright tree and this repository currently have no
single top-level project license, so do not describe the project as broadly
redistributable open source without resolving that boundary.
</details>

## Project map

| Path | Purpose |
|---|---|
| [`scripts/build-ios.sh`](scripts/build-ios.sh) | Complete Simulator or device build |
| [`scripts/package-ios.sh`](scripts/package-ios.sh) | Signed-package and game-data audit |
| [`patches/`](patches/) | HarkinianPad changes replayed onto pinned upstream source |
| [`docs/BUILDING.md`](docs/BUILDING.md) | Full build, signing, installation, and testing guide |
| [`docs/touch-controls-design.md`](docs/touch-controls-design.md) | Touch layout and input contract |
| [`docs/remaining-work.md`](docs/remaining-work.md) | Evidence ledger and remaining gates |
| [`ref/`](ref/) | Ignored local reference area; only its safety README is tracked |

Generated source trees, build directories, artifacts, ROMs, and ROM-derived
archives are ignored and must never be committed.

## Legal and acknowledgements

HarkinianPad is an unofficial community project and is not affiliated with or
endorsed by Nintendo or Harbour Masters. It does not provide the game, ROM
downloads, or playable ROM-derived data.

This project builds on Ship of Harkinian, libultraship, ZAPDTR, OTRExporter,
the Ocarina of Time decompilation project, SDL, and their contributors. All
projects, copyrights, and trademarks belong to their respective owners.
