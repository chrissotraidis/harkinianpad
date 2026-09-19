# Mod support: inspected behavior and next changes

Inspected 19 September 2026 against HarkinianPad's unchanged Preview 5 source
base, Shipwright `da4e6dc3321bda48a313b162261156580bc376f4`. These are source
findings, not physical-device compatibility endorsements. No packs, ROMs or
third-party art are redistributed here.

## What is already present

- **Ship of Harkinian randomizer:** built into the game. Randomizer > General
  exposes Generate Randomizer. Its generator and runtime are one system; use a
  new randomizer save. The [official guide](https://www.shipofharkinian.com/randomizer)
  describes generating and sharing SoH JSON seeds.
- **Asset mods:** the existing Mod Menu recursively discovers `.o2r` and, when
  MPQ support is compiled in, `.otr` files under Documents/mods. Extract a
  downloaded distribution ZIP first; the Mod Menu intentionally excludes ZIPs.
  The app exposes Documents through Files. Preserve a pack's relative directory
  structure and restart after changing the list. This is source-supported;
  individual packs still need device testing against this exact build.
- **Alternate assets:** the Enable Mods control actually changes `AltAssets`.
  That selects `alt/` replacements; it is not proof that every loaded archive or
  non-alternate replacement has been disabled.
- **Code mods:** upstream describes maintained source branches and rebuilt
  executables. They are not interchangeable with asset packs. This port disables
  scripting; importing a shared library or N64 patch does not enable it.

## OoTR website compatibility

[OoTR](https://ootrandomizer.com/generator) and SoH Randomizer are distinct
implementations. OoTR's [setup guide](https://wiki.ootrandomizer.com/index.php?title=Setup)
uses an NTSC 1.0 ROM. Its [Main.py](https://github.com/OoTRandomizer/OoT-Randomizer/blob/Dev/Main.py)
invokes `patch_rom`, emits `.zpf` patches and/or patched ROMs, and applies
cosmetic and gameplay code/data changes. HarkinianPad extracts resources from a
supported original ROM and executes compiled native game code. Extracting a
patched ROM would not translate its altered N64 instructions into native code.

A JSON extension or matching seed number is not interoperability. The SoH drop
handler checks `version` and `finalSeed`; `SeedContext::ParseSpoiler` then expects
SoH item/location/settings/hint structures. Some lookups use inserting map
operators, and hash icon indexing lacks bounds checks. Do not offer arbitrary
OoTR spoiler logs to that parser as a conversion mechanism.

A possible **restricted adapter** would require a pinned OoTR version, explicit
mapping of all selected settings, item/check/entrance identifiers, starting
inventory and hints, and rejection of every unsupported feature. It must prove
identical item placement and required runtime behavior for deterministic fixtures.
It must not claim race, multiworld, encrypted-seed or full OoTR parity. This is a
separate feasibility project; the nearer-term supported route is SoH-generated
seeds with a reliable native import and validation flow.

## Community demand worth testing

These are recurring recommendations, not a measured ranking of all players.

| Candidate | Evidence and integration route | Qualification needed |
|---|---|---|
| OoT Reloaded | [Primary project](https://github.com/GhostlyDark/OoT-Reloaded), [recent recommendations](https://www.reddit.com/r/shipofharkinian/comments/1v3d9cx/asking_for_recommendation/) | Use the SoH variant, exact pack release and content hash; compare memory, loading, scene transitions and Metal rendering on iPad/iPhone. The old `OoT-Reloaded-SoH` repo was archived September 2026; avoid stale download links. |
| Djipi's 3DS Experience / Skilar's Art Plus Link | [Creator distribution](https://gamebanana.com/mods/477979), [mixing guide/community discussion](https://www.reddit.com/r/shipofharkinian/comments/1rcycyb/a_guide_to_an_elegant_oot_experience_reloaded_and/) | Asset/model and overlap tests; do not promise that combining with Reloaded is conflict-free. |
| Cel shading | [roborich's source/build release](https://github.com/roborich/Shipwright/releases/tag/9.2.3-celshade0.5), [community interest](https://www.reddit.com/r/shipofharkinian/comments/1ul0twp/a_great_way_to_play_oot/) | A renderer/code fork, not merely a texture archive. Compare its actual changes and Metal path in a later branch; do not upgrade this migration's upstream. |
| Other expansion / ROM hacks | [community discussion](https://www.reddit.com/r/shipofharkinian/comments/1w8rgmx/howcome_were_not_seeing_expansion_mods/) | Establish native source/runtime support individually. A ROM hack advertised for N64 emulators is not evidence of SoH compatibility. |

The current Reloaded [v11.0.0 release](https://github.com/GhostlyDark/OoT-Reloaded/releases/tag/v11.0.0)
contains a SoH HD O2R package (`oot-reloaded-v11.0.0-soh-o2r-hd.7z`,
626,160,013 compressed bytes). Its GLideN64 and rt64 variants are different
formats. Start qualification with HD rather than assuming a multi-gigabyte 4K
pack is appropriate on mobile; no memory/performance result has been measured.

## Concrete gaps in the current implementation

Source locations are relative to the Shipwright submodule:

1. `soh/soh/Enhancements/mod_menu.cpp::UpdateModFiles` keys packs by filename
   stem, so two different directories containing the same stem collide. It
   automatically adds newly found packs; the disabled column is commented out.
   A stable relative-path identity and persistent per-pack enable state are
   needed before calling this a dependable manager.
2. The menu says top entries override lower ones, while `UpdateModFiles` loads
   forward and `ArchiveManager::AddArchive` replaces each resource mapping with
   the latest archive. Verify and reconcile this with two synthetic overlapping
   resources, then preserve/migrate saved order explicitly. Do not silently
   reverse existing users' order during source maintenance.
3. `Context::ParseSpoiler` changes context while parsing and catches failures
   afterward. Validate a bounded complete document before mutation, reject
   unknown identifiers and report useful errors without seed/spoiler contents.
4. SDL desktop file-drop handling is present, but no native document-picker
   implementation was found. Merely copying a shared seed into Documents does
   not prove it is selectable. Add a Files picker for SoH seeds and packs,
   sandbox-relative storage, duplicate handling and cancellation recovery.
5. Maintenance now logs mod discovery, requested/load counts and duplicate-name
   counts at initialization. No per-pack paths or spoiler contents are added.
   Further diagnostics should identify the app/source build, format, load result, pack
   count and effective order without absolute container paths, save contents or
   spoiler data. Export only after a user request; no background upload.

## Bounded implementation order after maintenance

First harden SoH seed validation and add native import. Then repair the existing
Mod Menu's identity, disable and order behavior with migration tests. Qualify one
small synthetic pack followed by exact Reloaded/Djipi releases on hardware,
recording startup separately from gameplay. Keep saved games/settings intact;
removing a test pack is sufficient rollback. Next investigate the restricted
OoTR adapter and cel-shading code separately. None of those future features is
claimed to have shipped in Preview 5 or this maintenance PR.
