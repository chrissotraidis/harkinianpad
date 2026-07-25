# harkinianpad

Working repository for a native **iOS/iPadOS build of Ship of Harkinian**
(The Legend of Zelda: Ocarina of Time PC port) on top of
[libultraship](https://github.com/Kenix3/libultraship).

Controller-first, user-supplied ROM only. No Nintendo assets, ROMs, or
generated archives are ever committed to or distributed from this
repository.

## Layout

| Path | Purpose |
|---|---|
| `docs/ios-feasibility-and-implementation-plan.md` | The plan: verdict, architecture map, work breakdown, milestones, risks, open questions, reusability |
| `docs/findings/` | Raw cited investigation notes backing every claim in the plan (platform seam, rendering/JIT audit, SDL/audio/lifecycle, filesystem/extraction, prior art/licensing) |
| `scripts/clone-sources.sh` | Fetches Shipwright + submodules (libultraship, ZAPDTR, OTRExporter) into git-ignored `sources/`, pinned to the investigated revisions |
| `scripts/configure-ios.sh` | The settled `cmake -GXcode -DCMAKE_SYSTEM_NAME=iOS` invocation; configures libultraship today, full app pending plan work items 1–3 |
| `ref/` | **Git-ignored** local dump for your own legally acquired ROM, generated `.o2r`/`.otr` archives, and other reference material. Never merged or maintained on git — see `ref/README.md` |
| `sources/`, `build*/` | Git-ignored working directories created by the scripts |

## Getting started

```sh
scripts/clone-sources.sh        # fetch the pinned upstream source stack
scripts/configure-ios.sh        # macOS + Xcode: configure libultraship for iOS (works today)
scripts/configure-ios.sh --soh  # attempt the full app (expected to fail until work items 1–3 land)
```

Then work the plan in order: `docs/ios-feasibility-and-implementation-plan.md`
§C (work breakdown) and §D (milestones).

## Status

- Investigation complete; verdict: **feasible with named caveats, no hard blocker** (see plan §A).
- No code has been written yet; work item 1 (libultraship CoreAudio iOS fix) is first.

## Asset posture

You must own a legally acquired Ocarina of Time ROM. This repository's
`.gitignore` blocks ROM and archive file types repo-wide and quarantines
`ref/`; keep it that way. Details: plan §E (risks L1–L2) and
`docs/findings/05-priorart-licensing.md` §B3.
