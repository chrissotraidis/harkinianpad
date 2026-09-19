# Mod packs and randomizer support

Inspected 19 September 2026 against HarkinianPad's unchanged Preview 5 source
base, Shipwright `da4e6dc3321bda48a313b162261156580bc376f4`. These are source
findings, not physical-device compatibility endorsements. No packs, ROMs or
third-party art are redistributed here.

## Pack import in Preview 6

These controls ship in [Preview 6](https://github.com/chrissotraidis/harkinianpad/releases/tag/v0.1.0-preview.6), app version 0.1.0 build 6.

1. Download a **Ship of Harkinian** pack from its creator. Choose `.o2r`, `.otr`,
   or a ZIP containing those files. Extract `.7z` on a computer or with a trusted
   archive app first; renaming it does not convert the format.
2. Open **Settings > Mod Menu > Import Packs from Files**. Select one or more
   files. ZIP bundles retain the pack directory structure; unrelated files and
   configuration files are not installed. Large/cloud-hosted files take time.
3. Choose **Edit**, then enable the packs you want. **Enable All** is available
   with confirmation, but includes optional add-ons. Follow the creator's order
   and choose compatible alternatives. New packs start disabled.
4. The top visible enabled pack has highest priority. Use the existing arrows
   or drag ordering, then **Apply & Close** and reopen the app. **Cancel** restores
   the saved selection. **Disable All** preserves every pack file.
5. **Alternate Assets** switches `alt/` graphics. It does not unload archives;
   use per-pack disabling and restart to turn an entire pack off.

Existing installations retain their legacy enabled order on first migration.
Packs now use relative paths rather than filename stems, so identical filenames
in different folders are independent. Ambiguous legacy names select one
lexically first path; review duplicate packs after upgrading. The original
`gSettings.EnabledMods` setting is preserved for rollback; new selections live
in `gSettings.Mods.EnabledPaths`. Downgrading will not honor new per-pack disabling.

Imports use new `Documents/mods/Import-…` folders and never overwrite an existing
pack. Each selected ZIP/file succeeds or rolls back independently; a multi-file
selection reports partial failures. A staged directory becomes visible only
after successful copy and archive validation. Imported packages are capped at
16 GiB of pack payload per selected file or ZIP and 100,000 archive entries;
individual resources are capped at 256 MiB. OTRs must contain the readable
internal file list required by this runtime. Symlink discovery
is excluded. The same preflight runs before loading manually copied packs. Validation checks
container structure, not whether a pack's
resources are correct for this runtime. Keep backups of packs you edit in Files.

No pack, ROM, save or third-party artwork is bundled with HarkinianPad. No upload
or telemetry is added. Logs record scan/load/import counts and failure categories;
existing upstream archive diagnostics may include paths.

## Existing randomizer and code-mod boundary

**Ship of Harkinian Randomizer** is already built in. Randomizer > General exposes
Generate Randomizer; use a new randomizer save. The [official guide](https://www.shipofharkinian.com/randomizer)
describes SoH-generated JSON seeds. Native seed import/validation is separate
work and is not implemented by the pack importer.

**Code mods** need compatible native source and a rebuilt executable. This port
disables scripting. A shared library, N64 patch or patched ROM is not an asset pack.

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
| Darunia’s Joy music | [Creator release](https://github.com/DaruniasJoy/OoT-Custom-Sequences/releases) | SoH OTR music bundle imports; music playback and randomizer music settings still need runtime testing. |
| Cel shading | [roborich's source/build release](https://github.com/roborich/Shipwright/releases/tag/9.2.3-celshade0.5), [community interest](https://www.reddit.com/r/shipofharkinian/comments/1ul0twp/a_great_way_to_play_oot/) | A renderer/code fork, not merely a texture archive. Compare its actual changes and Metal path in a later branch; do not upgrade this migration's upstream. |
| Other expansion / ROM hacks | [community discussion](https://www.reddit.com/r/shipofharkinian/comments/1w8rgmx/howcome_were_not_seeing_expansion_mods/) | Establish native source/runtime support individually. A ROM hack advertised for N64 emulators is not evidence of SoH compatibility. |

Djipi's creator specifies SoH 9.0.0 or later (this port remains on 9.2.3) and
says Master Quest is not ready. For a custom Link model, disable the pack named
`02 Link's Textures (Delete if using a custom player model)` instead of deleting
it. The creator also identifies **Fix Out of Bounds Textures** and custom Link
cosmetics as possible crash triggers. These controls exist in this pin; follow
the [creator's current instructions](https://gamebanana.com/mods/477979) and test
one change at a time. Import never changes those settings automatically.

The current Reloaded [v11.0.0 release](https://github.com/GhostlyDark/OoT-Reloaded/releases/tag/v11.0.0)
contains a SoH HD O2R package (`oot-reloaded-v11.0.0-soh-o2r-hd.7z`,
626,160,013 compressed bytes). Its GLideN64 and rt64 variants are different
formats. Start qualification with HD rather than assuming a multi-gigabyte 4K
pack is appropriate on mobile; no memory/performance result has been measured.

## Validation and remaining compatibility work

Host tests compile the production catalog/importer and cover legacy migration,
duplicate stems, missing packs, disabled-state persistence, unusual names,
O2R/OTR import, nested ZIP packs, unsupported formats, traversal attempts,
pre-existing destinations, oversized files and whole-bundle rollback. Run
`scripts/test-mod-packs.sh` after building host dependencies to include OTR tests.

Exact downloads checked on 19 September 2026:

| Download | Import result | SHA-256 |
|---|---|---|
| Reloaded v11.0.0 SoH HD, extracted O2R | One 4,062,463,848-byte pack; 11,527 entries; all entry CRCs passed; copied bytes identical | `988f0e49c3e46a169c21c9c510a7ebf9b5d17a3ba660ca06721f6e2a2804ee07` |
| Djipi 6.0.2 `djipi_s_3ds_experience_tot_fix.zip`, GameBanana file 1810733 | 37 archives imported; outer ZIP payload reads and archive-open validation passed, including optional add-ons | 02ff6f7ecfddab85dbe33925ae23a68b76c13d1cef6dc27b82546075cd262404 |
| Darunia's Joy `daruniasjoy.otr`, rolling `latest` download | One music archive imported and opened | `7f0e3adaf9ce5f01af023ce1aeb36f8b38b8495ff1086e966294ee6626d6e63d` |

These are **container/import checks, not gameplay endorsements**. A separate,
ROM-free iPad Simulator harness exercised the production UIKit presenter,
cancellation delegate, multi-file import with partial failure, and one-shot menu
notification. It did not automate a person selecting Files entries or the game's
ImGui controls. Device and Simulator compilation are recorded with the PR.

Separate full-app Simulator runs with privately extracted supported game data
reached the rendered title sequence with Reloaded, Djipi (37 archives), and
Darunia's Joy enabled individually. Runtime counts matched the selected packs;
all 39 installed packs stayed disabled after a restart with an empty selection.
Selection was configured by the test, not by automated touch-menu interaction.
This establishes startup/loading only, not gameplay or music-playback correctness.

The remaining acceptance step is in-game enable/disable/order testing and memory,
loading, scene-transition and Metal rendering checks on iPad/iPhone. Reloaded's
4 GB on-disk size does not measure runtime RAM use. Test one pack first; mixed
Reloaded/Djipi configurations need their own acceptance and creator instructions.
No physical-device install, gameplay or performance result is claimed.

SoH seed parsing also still needs bounded, transactional validation before native
JSON import: the current parser mutates context while parsing and has unchecked
hash-array indexing. Arbitrary OoTR JSON must not be passed through as a conversion.

The cel-shading fork has a concrete Metal implementation: its selected
[libultraship commit](https://github.com/roborich/libultraship/commit/79a2d153f49ff515d70401c607b4a4998564e218)
changes `gfx_metal.cpp`, `gfx_metal_shader.cpp` and `default.shader.metal`,
alongside D3D/OpenGL. That improves feasibility; it does not establish iOS
compatibility or justify upgrading this maintenance branch.

## Rollback

The mod follow-up is separate from source-maintenance PR #23. Its baseline is
wrapper `932228f4b9740252000ee40064c09e6eb0658ef0` and Shipwright
`f46021a168be3c6e5de00e395d7ab3c2a8112482`. Select that baseline in a disposable
checkout, initialize its pinned submodules and rebuild with the established
signing identity. Do not reset another working checkout or uninstall an app.

Before using an older build, move newly imported `Import-…` directories out of
`Documents/mods` using Files: the older loader automatically enables discovered
packs and does not understand per-pack disable state. Keep saves and the complete
configuration intact. The private baseline checkout/restore and accepted packages
are retained in the modernization backup; no user data belongs in this repository.
