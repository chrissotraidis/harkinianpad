# Source maintenance qualification

## Scope and plan (19 September 2026)

Preserve Preview 5, the app repository and the exact upstream version. Work on
`codex/harkinianpad-source-maintenance`; do not include the primary checkout's
uncommitted README and build-history document.

1. Restore and hash-verify the complete private checkout, including nested Git
   history and accepted packages; prepare Preview 5 independently and compare it.
2. Record each component's base and prepared identity. Rehearse ordinary source
   commits preserving upstream history; replace production preparation only after
   exact source parity, keeping broader release-delivery questions explicit.
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

The starting production method was central patch/preparation. All nine patches were active;
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

## Maintained source and rights scope

Dedicated `codex/harkinianpad-ios` branches now retain the original upstream
ancestry in genuine GitHub-connected forks. Shared default branches are unchanged.
`sources.lock.json` and the root/nested gitlinks select exact commits:

| Component | Selected commit | Old preparation mapping |
|---|---|---|
| [Shipwright](https://github.com/chrissotraidis/Shipwright/tree/codex/harkinianpad-ios) | `79b0907efc2d5631effb35dea88192ee5fc4395d` | Seven Shipwright patches plus icon overlay become parity commit `be876f2c607ff3c96b08af05ba64ab912ca61e8d`; `f93801b` updates nested gitlinks/URLs; `79b0907` adds bounded mod-load logging |
| [libultraship](https://github.com/chrissotraidis/libultraship/tree/codex/harkinianpad-ios) | `535f82618996eed61efdc9298548bdb9a6270e09` | `libultraship-ios.patch` |
| [ZAPDTR](https://github.com/chrissotraidis/ZAPDTR/tree/codex/harkinianpad-ios) | `150d38a6569fa6c7a26cf1c7203e23f82ae19fec` | `zapdtr-ios.patch` |
| OTRExporter | `c5465ba0bbd02d80d6ba6beed15d049ab64f5d6d` | Unmodified upstream |

GitHub API verified parents: HarbourMasters/Shipwright, Kenix3/libultraship and
HarbourMasters/ZAPDTR. Fork metadata establishes ancestry, not licensing.
The pinned [upstream modding guide](https://github.com/HarbourMasters/Shipwright/blob/da4e6dc3321bda48a313b162261156580bc376f4/docs/MODDING.md)
explicitly instructs users to create GitHub forks, commit changes, push branches
and share builds. That is the affirmative project guidance for this narrowly
scoped GitHub-hosted maintenance workflow. The earlier blanket hold on all
source maintenance was too broad and is superseded by this assessment.
It does not create a blanket license for mixed game-derived material or resolve
broader source-archive/commercial/store distribution. No terms were changed and
no upstream maintainer was contacted.

Ordinary builds now consume immutable submodules and do not rewrite source.
Historical patches remain in `patches/` for comparison and rollback only.
libultraship's ImGui/StormLib package patches remain dependency exceptions owned
by its build integration: existing host/device builds exercise them, resolved
commits and diff hashes are in provenance. The graph still has tag-based
fetches and host package inputs. Full offline dependency/relink delivery and a
new binary release remain outside the completed source-maintenance claim.

### Updating source

Create a component branch from its selected commit, make ordinary source changes,
retain notices, and test the affected platform. Push to the existing fork, then
update its parent gitlink and `sources.lock.json` in a reviewable wrapper PR.
Compare against `upstream_commit` with `git diff` / `git log`; do not reset to a
new upstream tip or change another product's shared branch. An upstream upgrade
is a separate change with its own acceptance evidence.

## Verification and diagnostics

`sources.lock.json` records maintained commits and their original upstream bases.
`scripts/verify-sources.py` checks parent gitlinks, complete source content and
modes. Wrong pins, missing files and unknown edits stop the build without reset.
Bootstrap initializes missing submodules; an existing mismatched checkout is
preserved for inspection. The old patch entry point only verifies sources.

Build diagnostics now report UTC stage starts, elapsed time, failure stage and
exact source/prepared-tree identities. Products have a
`HarkinianPad.build.json` sidecar (packaged as `BUILD_PROVENANCE.json`) with wrapper revision/dirty state, Xcode/CMake/SDK,
app version, executable and port-archive hashes, plus resolved Git dependency
commits and tracked-diff hashes. Packaging rejects a stale or
missing report. This is build provenance, not complete dependency source delivery
or bit-for-bit reproducibility. Signed development bundles are not modified after
signing; the report remains outside the app payload. Existing runtime logs
already use timestamps, asynchronous Release logging, rotation, and controller
reconciliation events. The separate `79b0907` source commit adds mod discovery/request/load and duplicate-name
counts at initialization, without pack paths, seed contents or uploads. It does
not change mod ordering or enable behavior. Hardware observation remains pending.

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
must equal the original base and prepared identities respectively. The maintained parity commits preserve that comparison.

No device was installed, uninstalled or reset by this task. Reinstalling an old
IPA requires the owner's existing signing identity, entitlements and bundle ID;
update in place only after privately backing up the full app data container and
verifying identity compatibility. Do not uninstall to bypass a mismatch.

## Evidence recorded in this task

- Twelve source/provenance regression cases pass, including maintained parent
  gitlink/URL disagreement and source drift. Legacy comparison cases cover: valid pristine/prepared states, an extra
  edit inside a patched file, an extra file, changed executable mode, wrong pin,
  and missing source. Existing controller-slot regression and repository safety
  checks pass.
- Complete prepared source verifies: Shipwright 11,949 entries (including its
  icon overlay), libultraship 429, ZAPDTR 230, OTRExporter 176. There are no extra
  private source changes relative to the independently prepared Preview 5 input.
- Private maintained-source rehearsal commits, not published dependency pins:
  Shipwright `ef646ebe6886631bd8585810e4985c1b23bc46df`, libultraship
  `64c5ba695c67d294ae1002296872e2d7367c4d98`, ZAPDTR
  `53cb40a6ec694d1c34dd272ec26de799b28aad99`. Each retains upstream ancestry;
  reverse/reapply checks reproduce exact base/prepared Git trees. Bundles are
  private recovery artifacts, not a public corresponding-source delivery claim.
- Regenerated `soh.o2r` SHA-256
  `5807dda0adb3d6c1ede1df0f77d34f33407153dd898654a17fcff7409e63db5d`;
  all 1,042 extracted entries equal the anonymously retrieved Preview 5 archive.
  ZIP bytes differ, so byte-reproducible packaging is not claimed.
- Default iOS 14 rebuild failed during CMake's compiler probe: installed Xcode
  27.0/SDK 27 only supports deployment targets 15.0 and later. The preserved
  baseline cache records Xcode 26.6. The project default remains iOS 14; use a
  compatible Xcode selected with `DEVELOPER_DIR` to qualify that shipping floor.
  An explicit `DEPLOYMENT_TARGET=15.0` build is only additional compile evidence.

Maintained-source integration is under review in PR #23, not merged. Complete
offline release-source qualification and any new binary remain uncompleted.
[Mod support research](MOD_SUPPORT.md) records source-level compatibility,
community demand and the concrete follow-up work; no OoTR interoperability or
new hardware gameplay acceptance is claimed.
