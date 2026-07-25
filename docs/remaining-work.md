# HarkinianPad remaining work

This is the authoritative execution queue and proof log for the goal in
[`ios-feasibility-and-implementation-plan.md`](ios-feasibility-and-implementation-plan.md).
The detailed investigation in that plan and [`findings/`](findings/) remains
the technical baseline; this file records current state, tested evidence, and
the next reproducible gate.

## Goal

Deliver a reproducible, controller-first native iOS/iPadOS port of Ship of
Harkinian, from pinned upstream source inputs through a signed, installable,
documented build. A passing intermediate build or runtime gate is progress,
not completion.

## Invariants

- User-supplied, legally acquired ROM only.
- Never commit or distribute ROMs, ROM-derived `oot.o2r`/`oot-mq.o2r`
  archives, or extracted Nintendo assets. Shipwright's ROM-free `soh.o2r`
  port archive remains ignored source/build output and may be packaged into
  the app.
- `chrissotraidis/harkinianpad` is the only owned project repository and the
  only repository to which HarkinianPad work is pushed.
- Treat Shipwright, libultraship, ZAPDTR, and OTRExporter as pinned upstream
  source inputs. Keep every HarkinianPad-owned port change in this repository;
  do not publish project changes to forks of those inputs.
- Keep `ENABLE_SCRIPTING` hard-disabled for iOS.
- Keep engine-layer and application-layer changes separated within
  HarkinianPad's maintained patch/source layout.
- Treat local, CI, Simulator, physical-device, signing, audio, and controller
  evidence as separate gates.
- Make the smallest maintainable change for the first reproducible failure,
  then replay that gate.

## Repository and source boundary

| Tree | Role | Revision |
|---|---|---|
| `chrissotraidis/harkinianpad` | Sole owned project and publication repository | `e8d26103f3ef9385ba66a557e46d11e072f4a833` baseline |
| `HarbourMasters/Shipwright` | Pinned upstream source input | `da4e6dc3321bda48a313b162261156580bc376f4` |
| `Kenix3/libultraship` | Pinned upstream source input | `2bfbde3a72c119f8073ad762ec6be131dff5df66` |
| ZAPDTR | Shipwright-pinned upstream source input | `be1c68a79c2d9a463f1b176b5cc32cf9771bfeaf` |
| OTRExporter | Shipwright-pinned upstream source input | `c5465ba0bbd02d80d6ba6beed15d049ab64f5d6d` |

`scripts/clone-sources.sh` checks out these exact upstream revisions. Local
source checkouts are disposable build inputs under git-ignored `sources/`;
the durable implementation, patches, scripts, documentation, and evidence
belong to HarkinianPad.

## Milestone queue

| Milestone | Gate | State | Required evidence |
|---|---|---|---|
| 0 | Trackable, reproducible source inputs | Complete | Clean bootstrap resolves all pinned upstream revisions and asset ignores |
| 1 | Full Shipwright iOS product configures and links | Complete | Unsigned Xcode build succeeds for a concrete iOS destination |
| 2 | Metal renders a frame | Complete | Runtime capture/log from Simulator or device with user-provided archives |
| 3 | Stable title screen with audio and usable UI | In progress | Runtime, audio, scaling, and stability checks |
| 4 | Playable with MFi/Bluetooth controller | Pending | Physical controller playtest and supported capability results |
| 5 | Files import and on-device extraction | In progress | Clean-container ROM import through successful archive generation and boot |
| 6 | Lifecycle and persistence are correct | In progress | Suspend/resume/kill, interruption, settings, and save matrix |
| 7 | Signed, installable, reproducible package | In progress | Device installation plus complete build/package documentation |

## Active gate

**M6b — run the physical-device lifecycle, persistence, and audio-interruption
matrix.**

Expected:

1. Background and foreground are replayed repeatedly from active gameplay on
   a physical iPad/iPhone without a crash, GPU watchdog kill, simulation
   advance, or broken audio resume.
2. A settings change and an in-game save made immediately before background
   survive background termination and cold relaunch.
3. Headphone/Bluetooth route changes and a real audio interruption at least
   do not crash or permanently mute the app; subjective audio quality remains
   a separate human check.

M3's subjective audio check and M4's physical MFi/Bluetooth controller
playtest remain open hardware gates. M5's final no-desktop physical Files move
also remains open. Safe implementation work continues on M6 without treating
Simulator evidence as physical-device proof.

## Evidence log

### 2026-07-25 — Public clean-machine and package gate passed

- Expected: prove that a copy containing only HarkinianPad's maintained files
  can fetch the pinned inputs, apply every patch, build the complete arm64
  iPhoneOS app, and keep a ROM placed under ignored `ref/` out of the build.
- Clean scenario: `/tmp/harkinianpad-public-proof.qHIge1` began with no
  `.git`, `sources/`, build tree, or artifact tree. With the local ROM copied
  only into `ref/`, `scripts/build-ios.sh --device` cloned the four expected
  revisions, set every upstream push URL to
  `disabled://harkinianpad-upstream-input`, applied all four maintained
  patches, and generated the ROM-free port archive.
- Reproduced and fixed portability failure: the first fresh final link exposed
  libpng ARM NEON references without their implementation objects. The
  existing build cache had hidden the problem. Setting
  `CMAKE_OSX_ARCHITECTURES=arm64` in the maintained configure command made the
  target architecture explicit, included the correct libpng sources, and the
  complete clean replay then linked successfully.
- Product proof: the clean app reports platform `IOS`, minimum OS `14.0`, and
  SDK `26.5`. Its generated and bundled `soh.o2r` files both have SHA-256
  `bf80f7f6cc51d7e5303bcd3c1eba216bf45599c96d525d9aafae51f3c53aa382`.
  The audited unsigned IPA has SHA-256
  `13fdb078ee149a456b1b3b7a97fe53e88f8868cf25009ac491a7ed7ad3845726`.
- Asset boundary: neither the app nor IPA contains a ROM, `oot.o2r`,
  `oot-mq.o2r`, or `.otr` file. The ignored source ROM retained SHA-256
  `b73fed80827d148647e35474a829bdebb74d6f9636a52e04214ce2bb407ab581`.
  `REQUIRE_SIGNED=1` correctly rejected the unsigned app.
- Remaining boundary: this closes the public source/bootstrap, compile, and
  unsigned package-safety proof. There are still no local signing identities
  or provisioning profiles, so signed installation and the complete
  physical-iPad/controller acceptance matrix remain open.

### 2026-07-25 — M6e Simulator low-memory dispatch passed

- Expected: exercise the existing iOS `SDL_APP_LOWMEMORY` handler against a
  live rendered game before adding any cache-purge behavior, then verify
  process, rendering, and container-data continuity.
- Scenario: the iPad Pro 11-inch (M4), iOS 18.5 Simulator app was already
  running the animated title sequence as PID `6981`. LLDB attached briefly,
  resolved the loaded `SDL_PushEvent`, enqueued one synthetic
  `SDL_APP_LOWMEMORY` event (`0x102`), received return value `1`, and detached
  cleanly.
- Observed result: the app log recorded
  `[12:34:19.395] [gfx_sdl2.cpp:699] [warning] iOS reported low memory`.
  PID `6981` remained alive, and a fresh live capture showed the Metal title
  sequence still rendering. No cache or resource failure was reproduced, so
  no speculative purge logic was added.
- Integrity proof: the configuration remained
  `c885a309201c8cdc1d7140ad96f3bfbfc12a805fd16fceb614da019ac254c906`,
  `Save/global.sav` remained
  `f5356979f4b56ba0fdcc30ebaef330631855f5beb35367a537408545084f7199`,
  `oot.o2r` remained
  `c3f65f102c33429f7e7204d6056284c285b39d952f859a1e48ff05ff293e366f`,
  and the local source ROM remained
  `b73fed80827d148647e35474a829bdebb74d6f9636a52e04214ce2bb407ab581`.
- Boundary and next gate: this proves SDL queue delivery, handler dispatch,
  non-crashing continuation, rendering continuation, and data integrity in
  Simulator. It does not reproduce OS-generated memory pressure, prove useful
  memory reclamation, or cover a physical-device jetsam/watchdog decision.
  Those remain in M6b.

### 2026-07-25 — M4b controller playtest handoff made reproducible

- Expected: turn the still-blocked controller gate into one exact replay
  without changing Shipwright's established SDL controller architecture or
  adding the explicitly out-of-scope virtual gamepad.
- Built-product evidence: the current Simulator app declares
  `GCSupportedGameControllers` with the `ExtendedGamepad` profile and
  `GCSupportsControllerUserInteraction=true`. Its bundled
  `gamecontrollerdb.txt` retains SHA-256
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
  The live iPad configuration maps SDL controller button 6 to Start, button 0
  to A, and button 1 to B. Its displayed keyboard fallback is Space for
  Start, X for A, C for B, and WASD for movement; Enter is not mapped to
  Start.
- Availability result: a fresh USB/Bluetooth system-profiler query still
  found no connected game controller, so no navigation, gameplay, reconnect,
  rumble, or motion result is claimed.
- Documentation: `docs/BUILDING.md` now gives one controller connection and
  forwarding path, the title/file-select/gameplay/reconnect checks, explicit
  capability reporting, and the Simulator-versus-physical-device evidence
  boundary. No product code changed in this slice.
- Remaining blocker and next gate: connect a real controller, forward it to
  the Simulator for the first diagnostic pass, then repeat the complete
  checklist on a signed physical-device build. Only the latter closes M4.

### 2026-07-25 — M4a/M6d controller availability and interruption dispatch audited

- Expected: take the first feasible controller/audio-interruption gate, prove
  what the current binary already does, and avoid adding a second lifecycle
  abstraction unless a reproducible gap exists.
- Controller evidence: macOS exposed no USB or Bluetooth game controller.
  LLDB inspection of the live iPhone 17 Pro, iOS 26.5 Simulator returned an
  empty `GCController.controllers` array. The built Info.plist does declare
  `ExtendedGamepad` support and `GCSupportsControllerUserInteraction=true`,
  and the in-app SDL controller bindings remain present, but there was no
  controller with which to perform an input, rumble, gyro, or gameplay test.
  M4 therefore remains open.
- Interruption ownership: the linked SDL CoreAudio backend contains
  `SDLInterruptionListener`, registers for
  `AVAudioSessionInterruptionNotification`, pauses its AudioQueue on
  interruption begin, restarts it on interruption end, and retries resume on
  app activation. This is the platform-specific owner below HarkinianPad's
  existing app-background audio hook, so no duplicate observer was added.
- Runtime dispatch proof: with the app stopped under LLDB after startup, two
  synthetic notifications were posted against the live shared
  `AVAudioSession`: interruption type began (`1`) and ended (`0`). A resolved
  breakpoint on
  `-[SDLInterruptionListener audioSessionInterruption:]` reported
  `hit count = 2`, proving both notifications reached the linked SDL handler.
  After detaching, the animated Metal title sequence remained live.
- Integrity proof: the local iPhone `oot.o2r` retained SHA-256
  `81a25bb74b87f6562b21234e74011e1507b82db9467cc927fe00368ab6a32579`
  and the source ROM retained
  `b73fed80827d148647e35474a829bdebb74d6f9636a52e04214ce2bb407ab581`.
  The app was then terminated and the Simulator shut down cleanly.
- Boundary: this proves listener presence, begin/end dispatch, non-crashing
  recovery, rendering recovery, and data integrity in Simulator. It does not
  prove audible pause/resume, a real phone-call/Siri interruption, Bluetooth
  or headphone route changes, physical-device watchdog behavior, or any
  controller capability. Those remain in the M4/M6b physical matrix.

### 2026-07-25 — M5c device-aware, non-quitting first-run recovery passed

- Expected: verify the remaining normal first-run UX on a genuinely empty
  iPhone container and remove desktop-style quit behavior only where runtime
  evidence showed it was wrong.
- Reproduced failure: on disposable iPhone 17 Pro, iOS 26.5 Simulator
  `A563AAB0-DC09-40FF-8AF2-8DCF419B9AB1`, the previous build first offered
  `Yes`/`No`, then instructed an iPhone user to use `On My iPad >
  HarkinianPad` and exposed an `Exit` action that called `exit(0)`.
- Implementation: the normal iOS import path now uses single-action
  `Continue`, device-aware Files guidance, persistent `Rescan`, a retry state
  for missing archives or extraction exceptions, and a single final
  `Run Ship of Harkinian` action. The same compact-display helper already
  proven for menu scaling selects `On My iPhone` or `On My iPad`; extraction
  internals and fatal corrupt-bundle handling were not changed.
- Visual/runtime proof: the final compact prompt fit the full landscape safe
  viewport, said `On My iPhone > HarkinianPad`, and contained no quit button.
  Repeated empty rescans returned to the same prompt. Backgrounding to
  SpringBoard for the expected Files handoff and foregrounding resumed the
  prompt on the same PID (`1428`) without a crash.
- Build/package proof: the final arm64 Simulator and unsigned arm64 iPhoneOS
  builds both ended with `** BUILD SUCCEEDED **`. The audited replacement IPA
  is `artifacts/HarkinianPad-9.2.3-unsigned.ipa`, SHA-256
  `0aa1c19a4513df029a1ad22bc89d7080d71fe2324fb6d4cea7ac77144adbb81b`;
  it contains no ROM or ROM-derived archive, and `REQUIRE_SIGNED=1` correctly
  rejects it.
- Reproducibility: the focused
  `patches/shipwright-ios-first-run.patch` applied with `--check` after the
  maintained base patch in the clean pinned replay and produced a byte-for-byte
  matching `OTRGlobals.cpp`. The patch bootstrap is idempotent on the final
  tree. Its empty-argument handling was also changed from a Bash array to
  positional arguments after macOS Bash 3.2 reproduced an `unbound variable`
  failure under `set -u`.
- Cleanup and boundary: the disposable Simulator contained no ROM, archive,
  or save data and was deleted after the test. This advances the Simulator UX
  portion of M5; a physical no-desktop Files move/extraction/boot remains open,
  along with the hardware gates in M3, M4, M6, and M7.

### 2026-07-25 — M3c/M5b/M6c iPhone first-run and adaptive UI slice passed

- Expected: replay a clean first launch and on-device-style Documents scan on
  an iPhone-class Simulator, then make only the form-factor and lifecycle
  changes justified by that evidence.
- Failure-driven lifecycle fix: the first clean launch on an iPhone 17 Pro,
  iOS 26.5 Simulator crashed after an early
  `SDL_APP_DIDENTERFOREGROUND`. LLDB placed the fault in
  `Ship::Audio::SetPaused(bool)` while `OTRGlobals::RunExtract` was still
  running, before `Context` had constructed its Audio object. The iOS SDL
  lifecycle path now uses one null-safe audio helper, so early foreground and
  background events remain valid during extraction startup.
- First-run proof: a clean install presented the in-app Files guidance, found
  the user ROM in the app's Documents directory after **Rescan**, completed
  extraction in approximately 257 seconds, and rendered the animated title
  screen through Metal. The input ROM retained SHA-256
  `b73fed80827d148647e35474a829bdebb74d6f9636a52e04214ce2bb407ab581`;
  the iPhone run generated a local-only `oot.o2r` with SHA-256
  `81a25bb74b87f6562b21234e74011e1507b82db9467cc927fe00368ab6a32579`.
  Neither file entered the repository, app bundle, or IPA.
- Adaptive UI implementation: SDL reports a 480x320 usable landscape display
  on this Simulator. libultraship now keeps a 1x base style on compact iOS
  displays and its 2x tablet style when the shortest usable side is at least
  600 points. Shipwright defaults compact iOS displays to its 0.75x ImGui
  option and tablets to the existing 1.0x option; overlays follow the active
  font scale. This is a two-size platform rule, not a new scaling subsystem.
- Visual proof: live Settings, Audio, and Controls panels fit the iPhone
  landscape safe viewport with the main tabs, side navigation, labels,
  sliders, and controller bindings usable. The same build was update-installed
  on the preserved iPad Pro 11-inch (M4), iOS 18.5 Simulator; its full tablet
  menu remained readable and the animated title screen remained stable.
- Lifecycle/integrity replay: the iPad app backgrounded to SpringBoard and
  foregrounded on the same PID (`97836`) without a crash. Afterwards,
  `oot.o2r` retained SHA-256
  `c3f65f102c33429f7e7204d6056284c285b39d952f859a1e48ff05ff293e366f`
  and the source ROM retained
  `b73fed80827d148647e35474a829bdebb74d6f9636a52e04214ce2bb407ab581`.
- Build/package proof: the final arm64 Simulator and unsigned arm64 iPhoneOS
  builds both ended with `** BUILD SUCCEEDED **`. The audited unsigned IPA is
  `artifacts/HarkinianPad-9.2.3-unsigned.ipa`, SHA-256
  `df8b0b46234f37e24d487261f96845e092ae7060544aee8a238500b632a39196`;
  it contains no ROM or ROM-derived archive, and `REQUIRE_SIGNED=1` correctly
  rejects it.
- Reproducibility: all maintained patches applied with `--check` to clean
  local clones at the four pinned revisions and passed `git diff --check`
  under `/tmp/harkinianpad-iphone-replay.Li4Xy1`.
- Boundary and next gate: this closes the outstanding Simulator iPhone
  safe-layout and clean first-run checks. Physical Files movement, touch,
  controller, subjective audio, interruption, lifecycle, signing, and
  installation remain hardware gates. The final environment audit reported
  `No devices found`, zero valid code-signing identities, and zero local
  provisioning profiles, so those gates cannot be inferred or downloaded
  around; the active gate remains M6b.

### 2026-07-25 — M7b HarkinianPad-only CI contract updated

- Expected: replace the obsolete CI contract that allowed the full app to
  fail with one required, ROM-free proof of the product that now builds
  locally.
- Implementation: `.github/workflows/ios-build.yml` now runs only in
  HarkinianPad and uses one required `macos-15` job. It fetches the exact
  push-disabled source inputs, generates and audits `soh.o2r`, configures the
  full iOS app, builds the unsigned arm64 iPhoneOS target, runs the package
  audit, and requires the unsigned app to fail `REQUIRE_SIGNED=1`.
- Simplicity: the separate LUS-only job was removed because the full app build
  already compiles and links that exact engine input. The stale
  `continue-on-error` and “expected to fail” contract were removed.
- Local proof: workflow YAML parses, every embedded shell block is valid, and
  its archive-generation, device-build, package-audit, and signature-refusal
  commands have all passed in the current checkout. The maintained patch set
  also passed the clean-source replay recorded below.
- Boundary: no artifact is uploaded and no step has credentials or commands
  that publish to an upstream input. Remote Actions evidence remains pending
  because no commit or push was requested or performed.

### 2026-07-25 — M3b mobile menu and per-file iOS behavior slice passed

- Expected: finish the smallest testable part of plan items 9 and 10 so the
  port menu is readable, controller-first, and free of misleading desktop
  controls without broadly rewriting working cross-platform behavior.
- Engine implementation: libultraship now applies its established mobile
  2x ImGui style/font scale and matching overlay measurements on iOS as well
  as Android. This is kept as a narrow platform decision pending real iPhone
  safe-area and display-scale testing.
- App implementation: iOS always enables ImGui controller navigation, hides
  the user toggle plus desktop background-input/cursor controls, removes
  desktop keyboard-shortcut and spoiler-log drag/drop copy, exposes the
  fixed-display aspect option, and offers SDL as the only audio backend.
- Explicitly retained behavior: in-container atomic rename, `random_device`,
  SDL controller input, MSAA, and SDL/UIKit message boxes remain on their
  existing paths because each is available on iOS. Input-viewer and tracker
  widgets do not add their own 2x multiplier because the global mobile scale
  already covers them. The fatal-corruption hard-stop path still needs
  physical failure-path acceptance rather than a speculative rewrite.
- Simulator visual proof: the rebuilt arm64 app launched on the iPad Pro
  11-inch (M4), iOS 18.5 Simulator as PID `91359`. The live Settings,
  Audio, and Controls screens fit the landscape safe area with readable,
  unclipped tabs, sidebars, labels, sliders, and bindings. Audio showed only
  `SDL`; the desktop-only menu/background-input controls were absent while
  controller bindings remained available.
- Integrity proof: updated installation preserved the imported `oot.o2r`
  SHA-256
  `c3f65f102c33429f7e7204d6056284c285b39d952f859a1e48ff05ff293e366f`
  and `Save/global.sav` SHA-256
  `f5356979f4b56ba0fdcc30ebaef330631855f5beb35367a537408545084f7199`.
- Build/package proof: both the arm64 Simulator and unsigned arm64 iPhoneOS
  products rebuilt successfully. The latter remains an iOS 14.0 app built
  with the iPhoneOS 26.5 SDK. The final audited 25 MB unsigned IPA run produced
  SHA-256
  `96a26948a4e9355ac2725959f8bb67695d5e1a11972274d44803fd6eaf0dd456`;
  it contains the pinned ROM-free resources and no prohibited ROM or
  ROM-derived archive, and `REQUIRE_SIGNED=1` correctly rejects it.
- Reproducibility: the complete maintained Shipwright, libultraship, and
  ZAPDTR patches applied with `--check` to clean local clones at their pinned
  revisions and passed `git diff --check` under
  `/tmp/harkinianpad-ux-replay.BsZ1uF`.
- Repository boundary: the live upstream review was read-only. Draft
  `Kenix3/libultraship#1083` remains unchanged at head
  `09426197f53810b3547a7696f0d50349bdbb35a2`; its five-file patch does not
  cover these per-file UX decisions. HarkinianPad changes remain only in this
  repository, and upstream input checkouts keep disabled push URLs.
- Boundary and next gate: this completes the Simulator-readable portion of
  item 9 and the audited low-risk portion of item 10. Physical iPhone/iPad
  safe-area, touch, controller, audio, fatal-path, and lifecycle acceptance
  remain open. The active gate remains M6b on a connected physical device.

### 2026-07-25 — M7a package audit and build-documentation slice passed

- Expected: make the proven iPhoneOS product reproducibly packageable without
  weakening the user-ROM boundary, and document the remaining signing/device
  workflow without representing an unsigned artifact as installable.
- Implementation: `scripts/package-ios.sh` accepts only an iPhoneOS
  `HarkinianPad.app`, checks the app and the contents of bundled `soh.o2r` for
  prohibited ROM/ROM-derived data, verifies the IPA payload after packaging,
  and distinguishes unsigned output from a valid code signature plus embedded
  provisioning profile. `REQUIRE_SIGNED=1` makes those signing properties a
  hard gate.
- Documentation: `docs/BUILDING.md` now covers pinned-source bootstrap,
  ROM-free resource generation, device and Simulator builds, personal-team
  signing, audited packaging, installation boundaries, and the outstanding
  physical-device acceptance matrix.
- Replay proof: the final 110 MB unsigned arm64 app produced a 25 MB
  `Payload/HarkinianPad.app` IPA with no `__MACOSX` resource-fork entries.
  SHA-256 is
  `eccf6d08d1a53eb0774d2e07b029aff15548f394f31429844ef61e0d1bc09b11`.
  The default audit passed, while the same app was correctly rejected under
  `REQUIRE_SIGNED=1` because it has neither a device signature nor embedded
  provisioning profile. A copied-app negative fixture containing
  `forbidden-test.v64` was also rejected before packaging.
- Dependency failure and fix: the host archive replay exposed libultraship's
  unchecked STB download silently replacing `stb_image.h` with a zero-byte
  file after a network failure. The maintained libultraship patch now pins the
  exact raw commit URL, verifies SHA-256
  `c54b15a689e6a1f32c75e2ec23afa442e3e0e37e894b73c1974d08679b20dd5c`,
  reuses only a matching cached header, and otherwise fails the download
  instead of compiling corrupted input. The full host generator then passed
  and produced ROM-free `soh.o2r` SHA-256
  `e99735f5fe854ee08277bda9925b4f6e644686a6516a23d88453b99899622daa`.
- Final replay: device and Simulator products both rebuilt successfully with
  that archive and dependency guard. The updated Simulator install launched
  as PID `90123` and preserved the existing `oot.o2r`, save, and config hashes.
  All three final patches applied with `--check` and passed
  `git diff --check` in clean local clones under
  `/tmp/harkinianpad-final-replay.rZjCyW`.
- Boundary: this proves repeatable wrapping, signature/profile gating,
  archive structure, and the prohibited-data checks. It is deliberately
  labeled unsigned and is not installable on a standard device. No physical
  device is connected, and no Apple development team/profile is available, so
  signed archive export, installation, launch, and sideload renewal remain
  open.
- Next gate: M6b on a connected physical device; then replay the documented
  M7 flow with `REQUIRE_SIGNED=1`.

### 2026-07-25 — M6a Simulator lifecycle and durable-config slice passed

- Expected: handle all SDL iOS lifecycle events explicitly, flush durable
  settings before suspension/termination, stop rendering/audio/simulation in
  the background, and resume safely without restructuring the UIKit/SDL
  launcher.
- Implementation: libultraship now handles
  `SDL_APP_WILLENTERBACKGROUND`, `DIDENTERBACKGROUND`,
  `WILLENTERFOREGROUND`, `DIDENTERFOREGROUND`, `LOWMEMORY`, and
  `TERMINATING`. Background/termination save window settings through the
  existing `Context` window/config access, then synchronously save the config.
  SDL audio has a narrow pause/resume hook that clears stale queued samples.
  The SDL backend marks the frame unavailable while backgrounded.
- Loop safety: a reusable `WindowIsFrameReady()` C bridge pumps lifecycle
  events and yields briefly when no frame may run; the iOS graph loop checks
  it before `RunFrame()`. Pixel-depth preparation/readback also returns early
  when the window is not frame-ready, so no stale Metal texture is touched.
- Failure-driven fix: the first replay exposed a real `SIGSEGV` after the
  second background transition. The crash report identified
  `GfxRenderingAPIMetal::GetPixelDepth` reading an invalid `MTLSimTexture`
  while backgrounded. The frame-ready depth guard stopped that fault; the
  graph-loop gate then stopped the non-rendering game simulation from spinning
  ahead while suspended.
- Build proof: the final arm64 Simulator product rebuilt and linked
  successfully from the maintained patches. The matching unsigned arm64
  device product was rebuilt against the iPhoneOS 26.5 SDK with an iOS 14.0
  deployment target. `vtool` reports platform `IOS`, minimum iOS `14.0`, and
  SDK `26.5`; the product is an unsigned arm64 Mach-O with bundle identifier
  `com.example.harkinianpad` and version `9.2.3`. Diagnostics were pre-existing
  upstream warnings, not lifecycle errors.
- Runtime proof: on the iPad Pro 11-inch (M4), iOS 18.5 Simulator, three
  consecutive Files app background/foreground cycles each dwelled for
  20 seconds and returned to the live title sequence on the same PID
  (`76665`). During the first dwell the game log remained exactly 675 lines
  and 65,959 bytes while `shipofharkinian.json` advanced from
  `08:03:29-0500` to `08:04:22-0500`, proving simulation/render work paused
  while the durable config flush ran.
- Integrity proof: after the three-cycle replay, `Documents/oot.o2r` retained
  SHA-256
  `c3f65f102c33429f7e7204d6056284c285b39d952f859a1e48ff05ff293e366f`,
  `Save/global.sav` retained
  `f5356979f4b56ba0fdcc30ebaef330631855f5beb35367a537408545084f7199`,
  and the config retained
  `606ef1995dac0b0eebebea4d9bec2e36fc8af2bad40f0989f46ef05e470e3417`.
  No post-fix crash report was generated.
- Packaging safety: both final app bundles contain no `.z64`, `.n64`, `.v64`,
  `oot*.o2r`, or `.otr` file. Their packaged ROM-free `soh.o2r` hashes to
  `e99735f5fe854ee08277bda9925b4f6e644686a6516a23d88453b99899622daa`
  and `gamecontrollerdb.txt` hashes to
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
- Reproducibility: every maintained script passed `bash -n`; the Shipwright
  and libultraship patches reverse-applied cleanly, with ZAPDTR using its
  documented CRLF-safe `--ignore-space-change` mode. All three patches then
  applied with `--check` and passed `git diff --check` in clean local clones
  under `/tmp/harkinianpad-final-replay.rZjCyW`.
- Boundary: Simulator proves event delivery, synchronous config flush,
  graph/audio/render pause logic, Metal-safe resume, and container integrity.
  It does not reproduce a physical iOS suspension/watchdog, an active-gameplay
  save immediately before kill, a real phone-call interruption, route changes,
  or audible audio recovery.
- Hardware availability: `xcrun devicectl list devices` reported
  `No devices found`, so no physical-device behavior, installation, or signing
  claim is inferred from the successful unsigned device build.
- Next gate: M6b physical-device lifecycle, persistence, and interruption
  matrix. M3/M4/M5 hardware gates remain open in parallel.

### 2026-07-25 — M5a Files-visible import and Rescan slice passed

- Expected: a clean install exposes HarkinianPad in Files, replaces the
  desktop-only ROM chooser with usable iOS guidance, rescans the app's
  Documents folder correctly, runs the existing on-device extraction, and
  boots without reprocessing on the next launch.
- Initial implementation: this slice used an iPad-specific Files path plus
  `Rescan` and `Exit`; M5c above supersedes that prompt with device-aware,
  non-quitting recovery. The iOS ROM scan uses
  `std::filesystem::directory_iterator` and retains the full file path; this
  replaces the inherited Unix branch that `stat`ed and returned cwd-relative
  basenames.
- Build proof: both current products rebuilt successfully with the slice:
  `build-ios-soh/soh/Release-iphoneos/HarkinianPad.app` is an unsigned arm64
  iOS 14.0 app, and
  `build-ios-soh-sim/soh/Release-iphonesimulator/HarkinianPad.app` is the
  matching arm64 Simulator product. Each bundles ROM-free `soh.o2r` SHA-256
  `0435bbedf867dc95c8ce293c4cac9f268b9795acfeeaee946ca2de982ae80a9f`
  and pinned `gamecontrollerdb.txt` SHA-256
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`;
  neither contains a ROM, `oot*.o2r`, or `.otr`.
- Clean Files proof: after uninstall/reinstall on the iPad Pro 11-inch (M4),
  iOS 18.5 Simulator, the app first showed `No O2R Files`, then the new
  `Import ROM in Files` guidance. The Files app visibly exposed
  `On My iPad/HarkinianPad`, containing only app-created config/mod files.
- Rescan/extraction proof: a copy of the ignored user ROM was staged into that
  same Files-visible Documents folder as `oot-user.v64`. Choosing `Rescan`
  found it by full path, offered to process it, reached 100% in the existing
  responsive extraction UI, and produced a 32 MB `Documents/oot.o2r` with
  SHA-256
  `c3f65f102c33429f7e7204d6056284c285b39d952f859a1e48ff05ff293e366f`.
  Choosing `Run SoH` rendered the live title sequence. Terminate/relaunch
  returned directly to the game without another import or extraction prompt.
- Reproducibility: all maintained scripts passed `bash -n`; every patch
  reverse-applied cleanly to the current source trees; and all three patches
  applied with `--check` and `git diff --check` to fresh local clones under
  `/tmp/harkinianpad-patch-replay.zY17z4`.
- Boundary: Files visibility, guidance, Rescan, extraction, boot, and relaunch
  are proven in Simulator. The ROM copy into the Simulator Files-visible
  folder was host-staged because no external Files provider was configured;
  therefore the final physical-device, no-desktop Files move is not claimed.
- Remaining: perform that Files move from iCloud/external storage on a
  physical device, measure extraction memory/time there, and retain the open
  M3/M4/M6/M7 hardware/signing gates.
- Next gate: M6a lifecycle event handling and settings flush.

### 2026-07-25 — M3a objective title/audio/stability slice passed

- Expected: the Simulator build reaches a correctly scaled title screen,
  initializes its real audio backend, remains stable through the title
  sequence, and loads a deterministic controller mapping database. Subjective
  audio and physical-controller behavior are separate gates.
- Audio proof: the app log recorded
  `SDL Audio initialized: 2 channels, 32000 Hz` at `04:00:16.634` and again
  after an updated-install replay at `06:01:56.725`. This proves successful SDL
  audio-device initialization, not that a person heard correct output.
- Stability/UI proof: the iPad Pro 11-inch (M4), iOS 18.5 Simulator remained
  alive through repeated title-demo scene transitions for approximately two
  hours. Repeated live captures showed a stable landscape Metal surface, no
  clipping at the iPad safe areas, and a consistently centered `PRESS START`
  presentation.
- Controller-database failure and fix: the first log reported
  `Failed add SDL game controller mappings from "./gamecontrollerdb.txt"
  (Invalid RWops)` because the downloaded database was never copied into the
  iOS bundle. The iOS configure now pins SDL_GameControllerDB commit
  `03d390c37b1342fcb7d8d294cd9621ab9d640bb3`, verifies SHA-256
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`,
  fails configuration on download/checksum error, and copies the file into
  the app root. The rebuilt Simulator bundle contains the exact file and the
  updated-install log no longer reports the mapping-load error.
- Input boundary: Simulator hardware-keyboard capture was explicitly enabled.
  Neither the generated Caps Lock Start binding nor a temporary plain-letter
  Start binding advanced the title screen. This is recorded as an unproven
  SDL/iOS Simulator keyboard path; it is not evidence against, or for, a
  physical MFi/Bluetooth controller. No physical controller was connected to
  the host for the required M4 test.
- Upstream review: libultraship PR
  [`Kenix3/libultraship#1083`](https://github.com/Kenix3/libultraship/pull/1083)
  remains an open draft at head
  `09426197f53810b3547a7696f0d50349bdbb35a2`. HarkinianPad independently
  adopted the same iOS fullscreen exclusions. Its CoreAudio RemoteIO change
  was not adopted because HarkinianPad intentionally uses SDL audio and has
  objective SDL initialization proof; revisit only if subjective/interruption
  evidence shows SDL is insufficient. Its libzip feature-detection overrides
  were not adopted because both pinned iOS builds and first-run extraction
  pass without them. The PR does not cover HarkinianPad's bundle/data paths,
  packaging, controller database, Files import, persistence, or lifecycle
  work.
- Remaining: subjective speaker/headphone audio, file-select navigation,
  physical-controller playability/capabilities, Files-based import, lifecycle,
  persistence, signing, physical-device installation, and packaging remain
  unproven.
- Next gate: M5a clean-install Files import while the M3/M4 physical hardware
  gates remain open.

### 2026-07-25 — M2 clean first-run extraction and Metal frame passed

- Expected: the same patched source tree builds for an arm64 iPad Simulator,
  accepts only user-supplied game data, generates its ROM-derived archive in
  writable app storage, and renders through Metal.
- Build proof: CMake generated the `SIMULATORARM64` Xcode project against the
  iPhoneSimulator 26.5 SDK with target triple
  `arm64-apple-ios14.0-simulator`. Xcode rebuilt
  `build-ios-soh-sim/soh/Release-iphonesimulator/HarkinianPad.app`
  successfully. `vtool` reports platform `IOSSIMULATOR`, minimum iOS `14.0`,
  and SDK `26.5`.
- Port-archive proof: the official upstream `GenerateSohOtr` target ran with
  `--norom` and produced a 4.2 MB `soh.o2r` containing 1,042 Shipwright custom
  files and no ROM or `oot*.o2r` entry. The ignored source archive and bundled
  app copy both hash to
  `0435bbedf867dc95c8ce293c4cac9f268b9795acfeeaee946ca2de982ae80a9f`.
  `scripts/generate-port-archive.sh` now owns this host generation and rejects
  ROM-bearing output.
- First failure and fix: the initial launch reported `Extractor assets not
  found` because libultraship treated Documents as both writable storage and
  the read-only bundle root on iOS. `GetAppDirectoryPath()` remains Documents,
  while `GetAppBundlePath()` now resolves the actual `NSBundle` resource path.
  The next launch accepted the extractor metadata and exposed the expected
  missing-port-archive gate.
- Packaging proof: the iOS post-build step now copies only the ROM-free
  `soh.o2r` to the app root. The final `.app` contains that resource and zero
  `.z64`, `.n64`, `.v64`, `oot*.o2r`, or `.otr` files.
- Clean-container proof: on an iPad Pro 11-inch (M4), iOS 18.5 Simulator
  (`08636791-2675-4675-8335-EF72EF954DCF`), HarkinianPad was uninstalled and
  reinstalled. The fresh Documents directory received only the ignored,
  user-supplied `oot-user.v64`. The app found its bundled port archive,
  prompted to process the ROM, reached 100%, and generated a 32 MB
  `Documents/oot.o2r` with SHA-256
  `fad9c501911c93f448a3d309e80a0d598817b1b0125d2609703348553e6bd396`.
- Runtime proof: choosing `Run SoH` rendered the libultraship splash, the
  opening horseback sequence, and a correctly scaled landscape
  `PRESS START` title screen. This is live game rendering, not a placeholder.
- Remaining: stable title/file-select input, objective and subjective audio,
  sustained runtime, physical controller, Files-based import, lifecycle,
  persistence, signing, device installation, and packaging gates are not yet
  proven.
- Next gate: M3a title input, audio, scaling, and sustained stability.

### 2026-07-25 — M2a native bundle and SDL UIKit entry point passed

- Expected: the linked product becomes a deliberate iPhone+iPad app bundle
  with stable metadata, and SDL's UIKit wrapper owns `main` while Shipwright
  provides `SDL_main`.
- Observed: the unsigned rebuild ended with `** BUILD SUCCEEDED **` and Xcode's
  bundle validation completed without the earlier orientation or launch
  warnings. It produced
  `build-ios-soh/soh/Release-iphoneos/HarkinianPad.app`.
- Bundle verification: the processed plist reports display name and executable
  `HarkinianPad`, identifier `com.example.harkinianpad`, version `9.2.3`,
  minimum iOS `14.0`, device families `1` and `2`, landscape-only full-screen
  operation, Files sharing and in-place document access, and extended-gamepad
  support with controller use recommended on iOS.
- Entry-point verification: `nm` reports Shipwright's `_SDL_main`, SDL UIKit's
  `_main`, and its `UIApplicationMain` dependency in the final arm64 Mach-O.
  The bundle is intentionally unsigned and contains zero `.z64`, `.n64`,
  `.v64`, `.otr`, or `.o2r` files.
- Reproducibility: all three HarkinianPad-owned source patches applied with
  `--check` to clean local clones at the documented Shipwright,
  libultraship, and ZAPDTR pins; every resulting tree passed `git diff
  --check`.
- Remaining: no Simulator or physical-device launch, Metal frame, game-data
  extraction, audio, controller playtest, lifecycle behavior, signing, or
  installation has been proven.
- Next gate: M2b arm64 iPad Simulator configure/build and first launch capture.

### 2026-07-25 — M1 full unsigned iOS app build passed

- Expected: the full pinned Shipwright product configures, compiles, and links
  for a concrete iOS destination with scripting and initial netplay features
  disabled.
- Observed: CMake generated an Xcode project for the iPhoneOS 26.5 SDK with
  target triple `arm64-apple-ios14.0`. Xcode compiled the full product and
  ended with `** BUILD SUCCEEDED **`, producing
  `build-ios-soh/soh/Release-iphoneos/soh.app`.
- Artifact verification: `file` reports an arm64 Mach-O executable;
  `LC_BUILD_VERSION` reports platform 2, minimum OS 14.0, SDK 26.5; Xcode's
  validation utility accepted the bundle; `codesign` confirms the proof
  artifact is intentionally unsigned. The bundle is 105 MB and contains the
  executable, plist, package marker, and extractor XML files, with no ROM or
  generated `.o2r`/`.otr` archive.
- Fixes made during replay: added deterministic HarkinianPad-owned patches for
  Shipwright, libultraship, and nested ZAPDTR; fetched and statically linked
  portable iOS dependencies; hard-disabled scripting; excluded initial
  SDL2_net features; converted GNU linker flags to Apple equivalents; selected
  SDL audio instead of the macOS-only CoreAudio HAL path; excluded native
  macOS fullscreen calls; and compiled the portable Darwin speech synthesizer
  for iOS.
- Remaining: the generated bundle metadata is generic: it has no stable bundle
  identifier or document/controller declarations and advertises only iPhone
  device family. Launch, Metal, audio, assets, Simulator, physical device,
  controller, lifecycle, signing, and installation remain untested.
- Next gate: M2a iOS/iPadOS bundle metadata plus the SDL UIKit entry point,
  followed by another unsigned device build.

### 2026-07-25 — repository boundary corrected

- Required boundary: `chrissotraidis/harkinianpad` is the project. All other
  repositories are references or pinned build inputs.
- Correction: Shipwright and libultraship forks were created during initial
  setup under an incorrect multi-repository assumption. No HarkinianPad
  implementation commits were committed or pushed to them, and they are not
  publication targets for this goal.
- Verification: README, bootstrap script, and this authoritative queue now
  state the single-repository rule and use the upstream source URLs.
  Shipwright, libultraship, ZAPDTR, and OTRExporter all receive the local
  `disabled://harkinianpad-upstream-input` push URL after bootstrap; the
  current disposable checkouts were audited to match.
- Remaining: migrate the proven local source edits into a durable
  HarkinianPad-owned patch/source layout before resuming the full build.
- Next gate: M1 source-layout migration, then focused OTRExporter replay.

### 2026-07-25 — M0 clean source bootstrap passed

- Expected: the bootstrap resolves the upstream source inputs at the exact
  investigated revisions while Nintendo asset types remain ignored.
- Observed: Shipwright resolved
  `da4e6dc3321bda48a313b162261156580bc376f4` from
  the maintained local checkout; libultraship resolved
  `2bfbde3a72c119f8073ad762ec6be131dff5df66` from
  the maintained local checkout; ZAPDTR and OTRExporter resolved
  `be1c68a79c2d9a463f1b176b5cc32cf9771bfeaf` and
  `c5465ba0bbd02d80d6ba6beed15d049ab64f5d6d`.
- Verification: `scripts/clone-sources.sh` exited 0 after checking the
  libultraship SHA. `git check-ignore -v` confirmed `sources/`, `.z64`, and
  `.o2r` protection.
- Fix made during replay: braced `SHIPWRIGHT_PIN` before the Unicode ellipsis;
  without braces, Bash treated the adjacent character as part of the variable
  name under the active locale.
- Remaining: no iOS build evidence exists locally yet.
- Next gate: M1a pinned libultraship iOS configure and unsigned build.

### 2026-07-25 — M1a pinned libultraship iOS build passed

- Expected: pinned libultraship configures and compiles as an unsigned arm64
  iPhoneOS library with Metal enabled and no scripting.
- Observed: CMake configured SDL 2.32.10 for iOS with Metal enabled and
  libzip with the iPhoneOS SDK's zlib/bzip2. Optional lzma and zstd support
  remained disabled. Xcode produced
  `build-ios-lus/src/Release-iphoneos/libultraship.a`.
- Verification: `cmake --build build-ios-lus --config Release` ended with
  `** BUILD SUCCEEDED **`; `lipo -info` reported arm64. A second clean flag
  replay compiled with `-target arm64-apple-ios14.0`.
- Fix made during replay: pass both `DEPLOYMENT_TARGET` (consumed by the
  fetched ios-cmake toolchain) and `CMAKE_OSX_DEPLOYMENT_TARGET`. Passing only
  the latter silently generated an iOS 13 project. The cache and generated
  Xcode project now both report iOS 14.0.
- Remaining: this proves the reusable engine library, not the Ship of
  Harkinian application target, app bundle, launch, rendering, or device
  behavior.
- Next gate: M1b unmodified full Shipwright iOS configure.

## External constraints

- GitHub Actions runs `30144805162` and `30144802099` never started a runner.
  GitHub reported failed account payments or a spending-limit requirement.
  This is an external pre-start block, not build evidence.
- Physical-device, signing, subjective audio, and controller gates remain
  untested.
