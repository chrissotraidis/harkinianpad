# Local Shipwright 9.3.1 qualification — 27 October 2026

The `codex/shipwright-9.3.1` branch integrates Ship of Harkinian 9.3.1
(`f0599f96f8d442f26d0fa1c5cedafddacd56633f`) and its libultraship base
`da6daf1a50a5e46d6641408d52227e31e85e46df`, preserving the maintained iOS
port. The exact resulting commits are in [sources.lock.json](../sources.lock.json).
This work is local and unreleased. App identity remains 0.2.1 build 8 for this
development proof; it must receive a new build identity before any future release.

## Integration

- Torch `2ab12fe9660aec04e02ee89fe81baed304a1a1d6` replaces ZAPDTR and
  OTRExporter. Runtime extraction uses the new YAML assets. The host CLI now
  accepts a ROM path and normalizes byte order before handing data to Torch.
- The portable Python generator matches all 1,056 entries of the new native
  `soh-o2r-packer`, including the 9.3.1 version record. Stale 9.2.3 digests fail
  closed. The retired iOS PNG fetch was removed with the old extractor.
- `.ootrs` music containers participate in the existing bounded import,
  enable/disable and restart workflow. Disabled packs never reach the new
  upstream music loader. Skipped music packs are reported accurately.
- iOS locale setup, disabled-networking GUI entries and the new controller
  mapping editor were reconciled with the maintained startup/reconnect code.
- Sanitizer testing found and fixed a null resource-metadata dereference in
  trace-level destruction logging; the regression test exercises that teardown.

## Metal investigation

Backported upstream libultraship [#1143](https://github.com/Kenix3/libultraship/pull/1143)
(`621f09b`) and the interpreter changes from
[#1172](https://github.com/Kenix3/libultraship/pull/1172) (`aca5863`). These reshape
single-line RAW uploads into image/tile dimensions before texture creation,
including loads below the GPU width limit. Six tests execute the real
interpreter and inspect upload dimensions and pixel bytes at 8,192 and 16,384
maximum widths. Four tests fail against the old interpreter; all six pass with
the fixes. Ordinary rows, direct uploads and bounded resource reads are covered.

Metal API validation also exposed an independent Simulator-only startup abort:
`Depth Clip Mode is not supported on this device`. Simulator builds now retain
the default clip mode rather than requesting depth clamping. Physical devices
retain the existing depth-clamp path. This follows the platform distinction in
[Apple's Simulator guidance](https://developer.apple.com/documentation/metal/developing-metal-apps-that-run-in-simulator)
and the same limitation recorded by [SDL](https://github.com/libsdl-org/SDL/issues/11692).

[Issue #22](https://github.com/chrissotraidis/harkinianpad/issues/22) remains open
and **is not established as fixed**. The reporter's complete Metal validation
sentence and exact physical-device reproduction are still needed. The report
also occurs without texture packs; the RAW upload defect alone does not prove
its cause.

## Verified locally

| Check | Result |
|---|---|
| Full libultraship native suite with AddressSanitizer and UndefinedBehaviorSanitizer | 435/435 pass, halt on UB enabled |
| Wrapper suite on Apple's Python 3.9.6 | 30/30 pass, no skipped SDL backport tests |
| Native controller-slot and mod-pack regressions | Pass, including OTR fixtures and direct/bundled `.ootrs` validation/rollback/selection |
| Portable port-resource comparison | All 1,056 entry names and bytes match the native packer |
| Native ROM extraction | `.v64`, `.z64`, `.n64` variants of the same supported input produce identical archives; malformed input rejected |
| App extraction in a fresh iOS 27 Simulator container | Torch completes; all 39,057 archive entries match native extraction byte for byte |
| Simulator with Metal API validation | Title sequence, file select, adult daytime graveyard, Royal Family's Tomb entrance and Sun's Song room render without validation aborts |
| Simulator lifecycle smoke check | Tomb scene survives background/foreground with the same process; extracted archive and configuration survive relaunch and app replacement |
| iPhoneOS and ARM64 Simulator release builds | Both pass with Xcode 27.1 / SDK 27.1, minimum iOS 15 |
| Local unsigned packaging | Payload, ROM exclusion, licensing files and provenance pass; `REQUIRE_SIGNED=1` correctly refuses the unsigned build |

The first-run empty-state prompt was captured. App extraction was driven by a
launch argument pointing to a private ROM staged in the test container, not by
the interactive Files picker. No existing device data was used or replaced.
Runtime scene tests use the built-in boot-to-warp-point configuration and a
temporary debug save, not a modified executable or an existing player save.
The Sun's Song room was rendered, but the song-learning cutscene and walking
transitions were not exercised. Touch controls are visible in the captures;
their input behavior was not tested.

Metal **API** validation is enabled for runtime scene checks. With additional
GPU shader validation enabled, pipeline instrumentation fails with
`buffer binding has argument index 31 that is greater than 30`; that mode is
not qualified. Simulator rendering does not establish physical GPU behavior,
performance, audible output or gameplay acceptance.

## Remaining acceptance and preservation

- Reproduce Kakariko ↔ Graveyard, Royal Family's Tomb entry/exit and Sun's Song
  on the affected physical iPhone, with Metal validation and the complete error
  if it still aborts. Test child/adult, day/night and pause-menu framebuffer use.
- Exercise Files-provider import, touch controls, real controller mapping and
  reconnect, audio/interruption/background behavior, save persistence and
  audible `.ootrs` playback. The local Xcode installation lacks Simulator.app,
  so interactive Simulator controls could not be exercised here.
- Requalify current pins through the off-Mac CI matrix when publication is
  authorized. Historical CI on 9.2.3 is not evidence for these source pins.
- Draft [PR #28](https://github.com/chrissotraidis/harkinianpad/pull/28) still
  contains old patch-export snapshots and remains separate.

The wrapper and both modified component branches contain local commits that
have not been pushed. A fresh remote clone cannot fetch these pins yet. Keep
the task worktree and its component Git repositories; do not deinitialize or
remove it. Build logs, private test archives/screenshots and local source
backup bundles are under ignored `work/`; build outputs and the unsigned proof
package remain ignored. The primary checkout's pre-existing edits are intact.
During the initial integration, no GitHub state, release, physical-device
installation or release approval was changed. The subsequent local device
test is recorded below.

## Subsequent iPhone installation and performance check

The same build was signed locally and installed over 0.2.0 build 7 on the
maintainer's iPhone 14 running iOS 27.0.1. A full app-data backup was retained.
All ten original container files matched byte for byte after installation;
both save files and settings also matched after launch. The title screen and
9.3.1 runtime version were verified. No uninstall or public distribution occurred.

The first crash-diagnostic launch explicitly enabled `MTL_DEBUG_LAYER=1`.
After the user reported increased stuttering, the same binary was relaunched
with `MTL_DEBUG_LAYER=0`, preserving the 30 FPS / 1x resolution settings.
The user then reported that gameplay appeared back to normal. This strongly
implicates validation overhead in that session; it is not a code regression
diagnosis or a controlled benchmark. Validation was a launch environment
setting, not a default added to the app. Normal launches do not enable it.

A roughly 15-second Metal trace without validation showed nominal thermal
state and 463 displayed frames averaging 33.35 ms. Forty display intervals
exceeded 45 ms, with a maximum of 66.77 ms; average FPS alone does not establish
perfect pacing. The user nevertheless reported normal perceived performance.

Separately, upstream [#7284](https://github.com/HarbourMasters/Shipwright/pull/7284)
explicitly reintroduced audio stutter to resolve audio-engine races. That
change is in 9.3.1 but absent from the previous 9.2.3 build. Follow-up
[#7289](https://github.com/HarbourMasters/Shipwright/pull/7289) remains open as
of this check and was not applied. This is relevant if audio dropouts recur;
it is not established as the cause of this user's resolved symptom.

This local installation and user performance observation do not lift the
release hold. Subsequent targeted transition coverage is recorded below.

## Physical iPhone transition check — 27 October 2026

On the same iPhone 14 / iOS 27.0.1 installation, temporary child-Link debug
states were used with Metal validation off, 30 FPS and 1x resolution. Inputs
were delivered through iPhone Mirroring. The following completed without a
crash and were corroborated by the scene initialization log:

- Daytime Graveyard → Kakariko (`0x195`) → Graveyard (`0xe4`), using the
  actual walking transitions. The Graveyard pause menu also rendered.
- Royal Family's Tomb → daytime Graveyard (`0x50b`), twice. The second exit
  followed Zelda's Lullaby, the grave-opening cutscene and a normal drop into
  the tomb (`0x2d`). The initial tomb load used the debug scene selector.
- Sun's Song in the Graveyard reloaded the scene at night without a crash.
- Royal Family's Tomb → nighttime Graveyard (`0x50b`), using the actual exit
  after a separate debug load configured for night.

The nighttime walk-in attempt did not reach the entrance trigger; it is not
counted as a pass. Adult Link, the full tomb puzzle/Sun's Song acquisition
sequence, Metal-validation-enabled device transitions and the reporter's
iPhone 16 Pro Max / iOS beta remain unqualified. These narrower successful
checks do not establish that issue #22 is resolved on the affected device.

QuickTime's preview was black while iPhone Mirroring controlled the locked
phone, so no video recording is claimed. Local mirrored-screen screenshots,
console logs and preservation evidence are under ignored
`work/graveyard-test/`. The latest full pre-test backup is under ignored
`work/graveyard-before/`. Both save files were unchanged by the test. After
restoring the original configuration and relaunching normally with validation
off, SHA-256 comparisons matched both saves, the game configuration, ImGui
configuration, split data, preferences, ROM and game archive to the backup.
No source or build change was required and nothing was published.

Reproduction commands (run in the retained worktree):

```sh
/usr/bin/python3 scripts/verify-sources.py
/usr/bin/python3 -m unittest discover -s tests -p '*_test.py'
scripts/test-controller-reconnect.sh
scripts/build-ios.sh --device
scripts/build-ios.sh --simulator
scripts/test-mod-packs.sh
scripts/check-repo-safety.sh
scripts/package-ios.sh
```

The sanitizer suite uses the native libultraship test build under
`build-host-lus`, with sanitizer configure/build/run logs in `work/`.
The six texture tests call `Interpreter::ImportTextureRaw` with a recording
backend, so they require no copyrighted inputs or Metal device.
