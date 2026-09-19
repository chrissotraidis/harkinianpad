# Source maintenance qualification

## Scope and plan (19 September 2026)

Preserve Preview 5, the app repository and the exact upstream version. Work on
`codex/harkinianpad-source-maintenance`; do not include the primary checkout's
uncommitted README and build-history document.

1. Restore and hash-verify the complete private checkout, including nested Git
   history and accepted packages; prepare Preview 5 independently and compare it.
2. Record each component's base and prepared identity. Rehearse ordinary source
   commits privately; retain production preparation until redistribution and
   complete source-delivery questions are resolved.
3. Fail closed on unexpected source changes and pin mismatches; add useful build
   provenance and diagnostics without changing gameplay or upgrading upstream.
4. Run regression/build/package checks and document exactly what remains.

## Starting point

Public main and Preview 5: `c5963066e888d45e71c16cb63bba1f9cc9329639`.
[Preview 5](https://github.com/chrissotraidis/harkinianpad/releases/tag/v0.1.0-preview.5)
is iOS/iPadOS 0.1.0 build 5, unsigned for user-side signing. Its anonymously
retrieved IPA SHA-256 is
`f505c0837a984f881d158ef3524f53d476a778e6351afabff49b611bbf47cef2`.
It has no corresponding-source asset; the release body does not provide a
separate complete source bundle. This is an evidence gap, not a compliance verdict.

The production method is central patch/preparation. All nine patches are active;
`shipwright-ios-native-hud-touch-experiment.patch` is layered into production,
so its filename alone does not establish an unshipped feature. The copied app
icon is another preparation input. Device and ARM64 Simulator builds use the
same prepared trees. macOS is an archive-generation/test host, not a separately
published HarkinianPad platform. Android/tvOS are not shipping targets here.

| Component | Base | Role / terms |
|---|---|---|
| [Shipwright](https://github.com/HarbourMasters/Shipwright) | `da4e6dc3321bda48a313b162261156580bc376f4` | Game/app and custom port assets; no root license at selected pin |
| [libultraship](https://github.com/Kenix3/libultraship) | `2bfbde3a72c119f8073ad762ec6be131dff5df66` | Renderer, platform, audio, controllers; root MIT notice, component terms retained |
| [ZAPDTR](https://github.com/HarbourMasters/ZAPDTR) | `be1c68a79c2d9a463f1b176b5cc32cf9771bfeaf` | Extraction/archive tools; root MIT notice |
| [OTRExporter](https://github.com/HarbourMasters/OTRExporter) | `c5465ba0bbd02d80d6ba6beed15d049ab64f5d6d` | Unmodified archive exporter |

The existing `chrissotraidis/libultraship` repository is a GitHub-connected fork
of `Kenix3/libultraship` (live API verified). It can host a dedicated HarkinianPad
branch later without moving another app's pin or the fork's default branch.
No new public dependency history is published by this qualification.

## Required source-delivery decision

The selected Shipwright tree lacks a top-level license. Its
[modding guide](https://github.com/HarbourMasters/Shipwright/blob/da4e6dc3321bda48a313b162261156580bc376f4/docs/MODDING.md)
describes forks and distributing builds, but does not define a blanket grant
covering every game-derived source file and asset. HarkinianPad also reserves
rights to its integration code. Existing public availability and general task
authorization do not resolve that recorded uncertainty. Establish the permitted
scope for maintained Shipwright source/history and source-archive distribution
before publishing that migration. Do not infer that only commercial uses need
clarification. No upstream contact or license change was made.

libultraship also prepares ImGui and StormLib using dependency-package patches.
Its CMake dependency graph includes tag-based downloads and host package-manager
inputs. Merely committing the three main prepared trees would not establish a
complete, offline reproducible release. These smaller dependency exceptions need
exact resolved identities, unchanged-output checks, notices and source/relink
qualification where applicable before a release-completeness claim.

Production patches are deliberately retained while this gate remains open.
The source verifier is a preservation guard, not a completed migration.

## Verification and diagnostics

`sources.lock.json` records the four upstream pins, ordered patch layers and
icon overlay. `scripts/verify-sources.py` reconstructs their expected Git index
in temporary storage, then compares every source file's content and mode.
It rejects wrong revisions, missing files, extra unignored files and extra edits
even inside a correctly patched file. It never resets an input checkout.
`clone-sources.sh` and the patch driver accept an exact prepared tree unchanged,
or prepare an entirely pristine pinned tree. Partial/unknown states stop for
preservation and inspection. `--latest` is no longer a normal-build option.

Build diagnostics now report UTC stage starts, elapsed time, failure stage and
exact source/prepared-tree identities. Products have a
`HarkinianPad.build.json` sidecar (packaged as `BUILD_PROVENANCE.json`) with wrapper revision/dirty state, Xcode/CMake/SDK,
app version, executable and port-archive hashes. Packaging rejects a stale or
missing report. This is build provenance, not complete dependency source delivery
or bit-for-bit reproducibility. Signed development bundles are not modified after
signing; the report remains outside the app payload. Existing runtime logs
already use timestamps, asynchronous Release logging, rotation, and controller
reconciliation events. Additional runtime instrumentation is a separate pending
source change; no new runtime telemetry is claimed here.

The identity report contains no absolute paths, usernames, signing identities,
ROM names, save data or persistent device identifiers. Existing compiler and
runtime logs may contain paths; review those before sharing them. No upload is
performed. Report issues to HarkinianPad with the build identity and focused log
excerpt; uncertain platform problems are not automatically upstream bugs.

## Rollback

The primary checkout, its local edits, nested sources and known-good IPAs remain
untouched. A complete private backup and a separately restored copy were compared:
67,597 file/link entries matched content, mode or link target. Both copies are on
the same physical disk, so this is rollback protection, not disk-failure recovery.
Private paths and signing material are intentionally excluded from this document.

For this wrapper change, use a disposable checkout at Preview 5:

```sh
git worktree add --detach /tmp/harkinianpad-rollback c5963066e888d45e71c16cb63bba1f9cc9329639
```

Run the baseline build procedure there using separately preserved sources, never
resetting the active working source. Private prepared-source commits were also
reversed and reapplied in disposable component checkouts; the resulting Git tree
must equal the original base and prepared identities respectively. A future
maintained-source migration should preserve that same comparison.

No device was installed, uninstalled or reset by this task. Reinstalling an old
IPA requires the owner's existing signing identity, entitlements and bundle ID;
update in place only after privately backing up the full app data container and
verifying identity compatibility. Do not uninstall to bypass a mismatch.
