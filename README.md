# HarkinianPad

[![HarkinianPad iOS build](https://github.com/chrissotraidis/harkinianpad/actions/workflows/ios-build.yml/badge.svg)](https://github.com/chrissotraidis/harkinianpad/actions/workflows/ios-build.yml)

HarkinianPad is a controller-first native iOS and iPadOS port of
[Ship of Harkinian](https://github.com/HarbourMasters/Shipwright), built on
[libultraship](https://github.com/Kenix3/libultraship).

It builds the complete Shipwright application as an arm64 iPhoneOS product,
runs through SDL's UIKit entry point, renders through Metal, and performs
first-run Ocarina of Time extraction inside the app container. You provide
your own legally acquired supported ROM; HarkinianPad never ships Nintendo
game data.

> **Project state:** the full app builds and reaches the animated title screen
> on iPhone and iPad Simulator. The next acceptance step is a signed run on a
> real iPad with a Bluetooth/MFi controller. See
> [remaining work](docs/remaining-work.md) for the proof ledger.

## What works

| Area | Current evidence |
|---|---|
| Reproducible source | Exact Shipwright, libultraship, ZAPDTR, and OTRExporter revisions are pinned; HarkinianPad patches live in this repository |
| Native app | Complete Shipwright configures, compiles, and links for arm64 iOS 14+ |
| Rendering | Live Ocarina of Time scenes render through Metal on iPhone and iPad Simulator |
| First-run setup | Files-visible ROM discovery and on-device `.o2r` generation pass clean iPhone/iPad Simulator replays |
| Mobile UI | Adaptive iPhone/iPad menus, controller bindings, SDL audio settings, and non-quitting setup/retry flow |
| Lifecycle | Repeated Simulator suspend/resume, config flush, audio-interruption dispatch, and low-memory dispatch pass without breaking rendering |
| Packaging | ROM-free app/IPA auditing, unsigned proof packaging, and a strict signed-package gate |

Still requiring physical hardware: controller gameplay and capabilities,
subjective audio, a real Files import, lifecycle/save persistence under device
termination, signing, and installation. Simulator evidence is never presented
as physical-device evidence.

## Quick start

Requirements:

- macOS with Xcode and command-line tools
- [Homebrew](https://brew.sh)
- a legally acquired supported Ocarina of Time ROM for first-run extraction

Install the open-source build dependencies, then clone and build:

```sh
brew install cmake ninja pkgconf sdl2 glew nlohmann-json libpng \
  libogg libvorbis opus opusfile

git clone https://github.com/chrissotraidis/harkinianpad.git
cd harkinianpad

# Optional local holding area. Everything except ref/README.md is ignored.
cp "/path/to/your-supported-oot-rom.v64" ref/

scripts/build-ios.sh --simulator
```

The Simulator product is:

```text
build-ios-soh-sim/soh/Release-iphonesimulator/HarkinianPad.app
```

For an unsigned device compile proof:

```sh
scripts/build-ios.sh --device
scripts/package-ios.sh
```

The one-command build fetches the pinned upstream inputs, disables their push
URLs, applies HarkinianPad's maintained patches, generates the ROM-free
`soh.o2r`, configures Xcode, and builds the full application.

### Why the ROM stays separate

The compiler does not need or read your ROM. Keeping it under `ref/` is a safe,
ignored local convenience that also proves a clean checkout contains
everything needed to compile.

After installing HarkinianPad, place the ROM in its Files-visible Documents
folder—**On My iPad > HarkinianPad** or **On My iPhone > HarkinianPad**—and
choose **Rescan** in the app. Extraction produces `oot.o2r` only inside the
app container. Neither the original ROM nor that derived archive enters Git,
CI, the app bundle, or a packaged IPA.

## Run on a real iPad

Configure a unique bundle identifier and your Apple development team:

```sh
DEVELOPMENT_TEAM=ABCDE12345 \
BUNDLE_ID=com.yourname.harkinianpad \
scripts/build-ios.sh --device
```

If Xcode needs to register the iPad or create a provisioning profile, open
`build-ios-soh/Ship.xcodeproj`, select the `soh` scheme and your iPad, choose
your team under **Signing & Capabilities**, and build once.

Then:

1. Launch HarkinianPad on the iPad.
2. Move your supported ROM into **On My iPad > HarkinianPad** with Files.
3. Return to HarkinianPad and choose **Rescan**.
4. Leave the app open while it builds the local archive.
5. Pair an iOS-supported extended-gamepad controller and press Menu/Start at
   the title screen.

Before treating a device artifact as installable or sharing it, require the
signed-package audit:

```sh
REQUIRE_SIGNED=1 scripts/package-ios.sh
```

This command rejects Simulator products, missing signing/provisioning,
original ROMs, ROM-derived archives, and prohibited game data inside
`soh.o2r`.

Detailed instructions and the physical-device checklist are in
[Building HarkinianPad](docs/BUILDING.md).

## Repository map

| Path | Purpose |
|---|---|
| [`patches/`](patches/) | Durable HarkinianPad changes applied to pinned upstream inputs |
| [`scripts/build-ios.sh`](scripts/build-ios.sh) | Clean-machine full-app build entry point |
| [`scripts/clone-sources.sh`](scripts/clone-sources.sh) | Fetch and verify pinned, push-disabled source inputs |
| [`scripts/generate-port-archive.sh`](scripts/generate-port-archive.sh) | Generate and audit Shipwright's ROM-free app resource |
| [`scripts/package-ios.sh`](scripts/package-ios.sh) | Audit/signing gate and IPA packaging |
| [`docs/BUILDING.md`](docs/BUILDING.md) | Simulator, physical-device, controller, signing, and packaging guide |
| [`docs/remaining-work.md`](docs/remaining-work.md) | Authoritative milestone queue and evidence log |
| [`docs/ios-feasibility-and-implementation-plan.md`](docs/ios-feasibility-and-implementation-plan.md) | Architecture, implementation decisions, risks, and acceptance gates |
| [`docs/findings/`](docs/findings/) | Source-cited technical investigation |
| [`ref/`](ref/) | Ignored local ROM/reference area; only its README is tracked |

Generated `sources/`, `build*/`, `artifacts/`, ROMs, and ROM-derived archives
are ignored.

## Reproducibility and repository boundary

`chrissotraidis/harkinianpad` is the only HarkinianPad publication
repository. Shipwright, libultraship, ZAPDTR, and OTRExporter are fetch-only
upstream inputs. Their local push URLs are deliberately set to
`disabled://harkinianpad-upstream-input`.

Every HarkinianPad-owned source change is stored as a reviewable patch here;
nothing required to reproduce the port exists only in ignored `sources/`.
GitHub Actions uses the same `scripts/build-ios.sh --device` path documented
above and builds without a ROM.

## Scope

HarkinianPad is intentionally:

- controller-first, with no virtual on-screen gamepad in the initial scope;
- Metal-only on iOS;
- built with `ENABLE_SCRIPTING=OFF`;
- offline and ROM-user-supplied;
- focused on local development installation, not App Store submission,
  netplay, or SDL2_net.

## Legal and acknowledgements

HarkinianPad is an unofficial community port and is not affiliated with or
endorsed by Nintendo. It contains no Nintendo game assets. Users must supply
their own legally acquired supported copy of The Legend of Zelda: Ocarina of
Time.

This work builds on Ship of Harkinian, libultraship, ZAPDTR, OTRExporter, the
Ocarina of Time decompilation project, SDL, and their contributors. Those
projects retain their respective copyrights and licenses.
