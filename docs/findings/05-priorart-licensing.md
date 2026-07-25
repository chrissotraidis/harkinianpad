# Prior Art, Upstream Posture, and Licensing — iOS/iPadOS Port of SoH on LUS

Research date: 2026-07-25

## PART A — PRIOR ART

### A1. Does a working iOS port already exist? — LEAD FINDING

**No released/working iOS port of Ship of Harkinian (OoT) exists.** No .ipa, no App Store listing, no
AltStore/SideStore repo entry, no r/HarbourMasters or Discord post announcing a playable iOS build of SoH
was found.

**However, the closest real prior art is a sibling libultraship project, not SoH itself:**
**`Sunset-Dawn/SpaghettiKart`** — a fork of `HarbourMasters/SpaghettiKart` (the Mario Kart 64 decomp port,
built on the *same* Kenix3/libultraship stack and the same HarbourMasters/Discord ecosystem as SoH) shipped
a tagged release **"Bolognese Alfa 1.0.0-E"** that is explicitly an **iOS/iPadOS build**. Per the release
notes (indexed by search, page since returned HTTP 404 on direct fetch — repo/account appear to have been
deleted, renamed, or made private after indexing; treat as historical, not currently reproducible from that
URL):
- On-device ROM extraction with a **fullscreen iOS setup flow** to generate `mk64.o2r` (the O2R-format
  equivalent of what SoH calls `oot.o2r`).
- **iOS Files app import** support for ROMs, `spaghetti.o2r`, controller DB files, config, and mod archives.
- **Asynchronous extraction** with progress UI so the setup screen stays responsive while `mk64.o2r` builds;
  UI sized responsively for small iPhone screens.
- **On-device ROM discovery** from `Documents/Imports` and the app container; ROM validated via the existing
  MK64 hash-check path (analogous to SoH's `docs/supportedHashes.json` flow).
- Ported **Torch** (SpaghettiKart's asset-exporter, ZAPD/OTRExporter's counterpart) to run **on iOS as a
  static library**, with only the MK64 extraction backend enabled for the initial build, plus NAudio support
  added so MK64 audio assets can be generated on-device.
- Torch submodule was switched to a `Sunset-Dawn/Torch` fork specifically for iOS extraction feasibility.

This is a **materially complete, working, on-device-extraction iOS build of a libultraship-based decomp
port** — the single closest thing to "iOS SoH" that exists anywhere. It demonstrates the on-device
extraction/import/async-UI pattern an iOS SoH port would need is already solved once by someone in this
exact ecosystem. Caveats: (1) it is Mario Kart 64, not Ocarina of Time — different game, different repo,
different exporter (Torch vs ZAPDTR/OTRExporter); (2) the repo is currently inaccessible (404) as of this
research, so current maintenance/build status, licensing terms of that specific fork, and whether it was
ever installed on a real device outside CI cannot be independently verified beyond the indexed release notes
text; (3) no TestFlight/App Store/AltStore listing for it was found — distribution was presumably build-it-
yourself via Xcode.
Sources: https://github.com/Sunset-Dawn/SpaghettiKart/releases/tag/1.0.0-E (indexed text; live fetch 404),
https://github.com/HarbourMasters/SpaghettiKart, https://harbourmasters.github.io/SpaghettiKart/index.html

Other adjacent hits, none of which are iOS:
- `worleydl/shipdev` — unofficial SoH port to **UWP** (Windows Store), not iOS. https://github.com/worleydl/shipdev
- `Rinnegatamante/Shipwright` — fork by a prolific PS Vita/consoles homebrew porter; no iOS evidence found,
  likely a Vita/other-console angle given Rinnegatamante's usual platform focus.
  https://github.com/Rinnegatamante/Shipwright
- GBAtemp Wii U port thread (25+ pages) — no iOS discussion found in the Wii U thread.
  https://gbatemp.net/threads/ship-of-harkinian-ocarina-of-time-wii-u-port.612074/

### A2. Who added `__IOS__` support in upstream libultraship — PR-level history

Confirmed via `Kenix3/libultraship` PR search (`?q=is:pr ios`). This shows iOS support has been added,
broken, and re-fixed multiple times over ~2 years — a real but historically unstable feature, not a
one-and-done merge:

| PR | Title | Author | State | Date |
|----|-------|--------|-------|------|
| #491 | Added ios support | **KiritoDv** | Merged | Apr 28, 2024 |
| #534 | ci: improve caching for faster builds | briaguya0 | Merged | Apr 30, 2024 |
| #726 | readme update to test ios ci | briaguya0 | Closed | Dec 9, 2024 |
| #728 | Fixed ios compilation | **KiritoDv** | Merged | Dec 1, 2024 |
| #922 | ci: temporarily disable iOS | briaguya0 | Merged | Oct 1, 2025 |
| #966 | Mobile: Update deps for Android/iOS and add Android CI | **SternXD** | Merged | Feb 1, 2026 |
| #1056 | Add partial iOS support | ghost (account deleted) | Closed (repo deleted) | Apr 21, 2026 |
| #1083 | fix iOS support | **coco875** | **Draft, still open** | Apr 20, 2026 |
| #1114 | fix(crash): replace exit(1) with SDL_QUIT in ShutdownHandler | bassdr | Open, 1/3 approvals | May 30, 2026 |

Details and stated intent, per PR bodies/review threads:
- **#491 (KiritoDv, Apr 2024)** — original iOS support. Author's own words: "This PR adds simple IOS
  support, it should not break any other platform since everything is wrapped on PLATFORM_IOS." Reviewer
  briaguya0 flagged that parts duplicated Android logic and should live in the port layer, not core LUS —
  deferred as follow-up (issues #524 rename `OSXFolderManager`, #525 `GameMode` handling). Verified against
  a Shipwright-side integration PR (#4076) before merge. https://github.com/Kenix3/libultraship/pull/491
- **#728 (KiritoDv, Dec 2024)** — "Fixed ios compilation," single commit, no description, merged by Kenix3
  with no review comments — i.e. iOS had broken again and needed a fix within ~7 months of the original PR.
  https://github.com/Kenix3/libultraship/pull/728
- **#922 (briaguya0, Oct 2025)** — iOS CI was **disabled** ("ci: temporarily disable iOS"), no description
  given. Read together with #966, this means iOS was broken/unmaintained in CI for roughly 4 months (Oct
  2025–Feb 2026). https://github.com/Kenix3/libultraship/pull/922
- **#966 (SternXD, Feb 2026)** — fixed iOS build failures caused by an outdated SDL2/CMake incompatibility,
  updated Android+iOS deps, **re-enabled iOS CI, and added Android CI for the first time**. Notably gated on
  Kenix3's explicit sign-off ("I'm good with Android being added to CI") — i.e. the repo owner personally
  approves new mobile-platform CI, showing active (if selective) engagement rather than delegation.
  https://github.com/Kenix3/libultraship/pull/966
- **#1056 (ghost, closed Apr 2026)** — explicitly says it exists to "add the iOS-specific project files and
  build support **needed by SpaghettiKart**," "avoid selecting the CoreAudio backend on iPhone targets," and
  "add the iOS fullscreen stub used by the app integration." This directly corroborates the Sunset-Dawn
  SpaghettiKart iOS work in A1 — someone was upstreaming LUS-side prerequisites for that downstream iOS app.
  The PR was auto-closed because the author deleted their fork, not because it was rejected.
  https://github.com/Kenix3/libultraship/pull/1056
- **#1083 (coco875, Draft, Apr 2026, still open)** — picks up where #1056 left off, explicitly "partially
  based on #1056," relocates iOS `Launch.storyboard`/`plist.in` to the port side, improves Core Audio
  handling on iOS instead of stubbing it out, and states the author references **"a working implementation
  in a separate SpaghettiKart fork"** while still verifying "which changes are truly necessary." This is the
  live, currently-open state of upstream iOS work as of this research. https://github.com/Kenix3/libultraship/pull/1083
- **#1114 (bassdr, Open, May 2026)** — unrelated in intent (a signal-handler deadlock fix: `exit()` from a
  signal handler isn't async-signal-safe and deadlocks against audio-thread mutexes) but the author notes
  "recent rebasing didn't explain MAC/iOS CI/CD failures," i.e. iOS CI is *still* intermittently failing as
  of late May 2026. https://github.com/Kenix3/libultraship/pull/1114

**Net read:** iOS support in upstream LUS is real, has an active current owner-of-the-moment (coco875, via
draft PR #1083, explicitly working from a reference implementation), and is watched/gated by Kenix3
personally — but it has cycled through "added → broke → disabled → fixed → broke again" at least twice in
two years and is presently a **draft, not a stable merged baseline**. The pinned commit your sibling
investigation already confirmed (`port-maintenance` @ `2bfbde3`, Jul 2026) is downstream of PR #966 (iOS CI
re-enabled) but its exact relationship to the still-open #1083 draft was not independently re-verified here.

### A3. Android forks of SoH — concrete repos, technical approach

Multiple independent Android forks exist (none are officially merged into `HarbourMasters/Shipwright` as
first-class Android support, though the CMake/LUS side now has Android CI per #966 above):

- **`Waterdish/Shipwright-Android`** — https://github.com/Waterdish/Shipwright-Android
  - Renderer: **OpenGL ES 3.0+** (matches LUS's documented Android backend, see B/PORTING.md below).
  - Min target: Android 7.0+, tested on Android 15.
  - Asset extraction: **on-device, interactive** — app prompts the user to locate their ROM and generates
    the `.otr` on first launch; subsequent launches skip the dialog unless the user deletes the `.otr` files
    from the device's SOH folder.
  - Input: touch controls + physical controller support; Back/Select opens the Enhancements menu. Known
    bugs: some controllers mis-map, and controllers that reconnect mid-session don't re-trigger the menu.
  - Explicitly labeled "Original Repository: HarbourMasters/Shipwright" — a platform-specific fork, not a
    contribution path back to upstream; no stated merge-upstream plan in the README.
  - 568 stars, 87 open issues — active community interest, ongoing rough edges.
- **`linkzenic/Shipwright-Android`** — distributes prebuilt "Standard SOH" and "SOHCS" (cel-shaded) APKs from
  its Releases page. https://github.com/linkzenic/Shipwright-Android
- **`linkzenic/2ship2harkinian-Android`**, **`Waterdish/2ship2harkinian-Android`**,
  **`robertkirkman/2ship2harkinian-Android`** — same pattern applied to 2 Ship 2 Harkinian (Majora's Mask
  port), forked from Waterdish's original Android work.
- **`izzy2fancy/Zelda-OOT-Android`** — another independent Android port repo.

All of these are **out-of-tree, community-maintained hard forks** — none appear to be a thin platform layer
merged upstream; each carries its own copy of the SoH source tree.

### A4. Upstream posture on iOS — stated vs. implied

**Stated (explicit, in official docs):** `Kenix3/libultraship`'s own porting guide
(`docs/PORTING.md`, read from the locally pinned `port-maintenance@2bfbde3` checkout) lists a **formal
platform support matrix**:

| Platform | Rendering Backends |
|---|---|
| Windows | OpenGL, Direct3D 11 |
| macOS | OpenGL, Metal |
| Linux | OpenGL |
| **iOS** | **OpenGL, Metal** |
| **Android** | **OpenGL ES** |
| OpenBSD | OpenGL |

iOS is listed as a first-class supported platform in this document, on equal footing with Windows/macOS/
Linux — not flagged experimental. The main `README.md` (both `main` and the pinned `port-maintenance`
checkout) gives iOS its own build-instructions section: "Requires Xcode on macOS. Set
`CMAKE_OSX_DEPLOYMENT_TARGET`..." with a working `cmake -GXcode -DCMAKE_SYSTEM_NAME=iOS` invocation, right
alongside Android's NDK-based instructions. Source (local): `lus-pinned/docs/PORTING.md` lines 9–20;
`lus-pinned/README.md` lines 53–58.

No standalone "we do/don't support iOS" statement from Kenix3 outside PR review comments was found (no
blog post, Discord digest quote, or interview surfaced by search). The clearest first-person signal is
Kenix3's PR #966 review comment "I'm good with Android being added to CI" — a case-by-case gatekeeping
posture, not a blanket roadmap commitment either way.

**Switch/WiiU build confirmation (from local trees):**
- `soh/CMakeLists.txt` has explicit `if (CMAKE_SYSTEM_NAME STREQUAL "NintendoSwitch")` and
  `CMAKE_SYSTEM_NAME MATCHES "Windows|NintendoSwitch|CafeOS"` conditionals (lines 129, 309, 315) — i.e.
  Switch and Wii U (CafeOS) build paths are **wired directly into the mainline Shipwright build**, not
  bolted on by a separate hard fork of the whole game repo.
- `soh/.gitmodules` pins the `libultraship` submodule to **`https://github.com/kenix3/libultraship.git`,
  branch `port-maintenance`** — the *same* upstream repo/branch that carries the `__IOS__` code, not a
  separate `libultraship-switch` fork. This means Switch, Wii U, and (per PORTING.md) iOS/Android are all
  meant to be served from one consolidated upstream branch.
- Legacy per-console hard forks of the *library* still exist in GitHub's fork network
  (`HarbourMasters/libultraship-switch`, `HarbourMasters/libultraship-wiiu`, plus several further forks of
  each by other users) — but given `port-maintenance` on the main repo already carries Switch/CafeOS/iOS/
  Android code and is what `soh`'s own `.gitmodules` actually points to, these look like **earlier-era,
  now-largely-superseded staging forks** rather than the live integration point.
  `HarbourMasters/libultraship-wiiu` itself shows continued commits (README reports "1,001 commits on main
  branch," no explicit staleness statement) but the locally pinned `lus-wiiu` checkout's HEAD commit is
  **Jan 2, 2025** ("wiiu: Update Fast3D APIs") — i.e. **over 18 months stale relative to the Jul 2026
  `port-maintenance` pin** used for this investigation. Read together, that supports "WiiU-specific fork is
  stale; the live consolidation point is `port-maintenance`" rather than "WiiU fork is where new work
  lands." Source (local): `lus-wiiu` git log; https://github.com/HarbourMasters/libultraship-wiiu

### A5. Strategy assessment

Given the above, three paths are live options, with different levels of fit:

1. **Upstream contribution to `Kenix3/libultraship` `port-maintenance`.** This is where Switch/Wii U/Android
   iOS code *already* lives, where Kenix3 personally reviews and gates mobile-platform changes, and where an
   iOS-focused contributor (coco875) is *actively working right now* (open draft PR #1083, referencing a
   reference iOS implementation). This is the path of least resistance for anything below the SoH-app layer
   (SDL/Metal backend plumbing, CoreAudio on iOS, mobile input shim in `src/ship/port/mobile/`) — you would
   likely be extending/collaborating on work already in flight rather than starting from zero, and it avoids
   permanently forking a library that's still receiving upstream love. Coordination risk: iOS support has
   broken/been disabled twice in two years, so anything landed upstream needs its own CI coverage or it will
   silently bit-rot again (as happened Oct 2025–Feb 2026).
2. **A dedicated platform fork of `soh` itself for iOS app-layer bits (Info.plist, on-device extraction UI,
   Files-app import, TestFlight/App Store packaging)** — mirroring exactly what `Waterdish/Shipwright-Android`
   and the (now-inaccessible) `Sunset-Dawn/SpaghettiKart` iOS build both did. This is the pattern every
   existing successful mobile port in this ecosystem has actually used: LUS/upstream carries the
   cross-platform engine plumbing, and a **separate app-shell fork carries the platform-specific UI/packaging/
   distribution glue**. Given no official Android *or* iOS app-layer has ever been merged into
   `HarbourMasters/Shipwright` itself, expecting the SoH repo maintainers to accept an iOS app shell in-tree
   is a weaker bet than expecting `libultraship` to accept the underlying engine work.
3. **Downstream overlay/out-of-tree fork of the whole `soh` repo**, like most Android ports. Fastest to ship
   independently, but forfeits any upstream engine improvements automatically and is the pattern every SoH
   Android fork has ended up in — divergent, single-maintainer-risk repos with dozens of open issues each.

**Recommended framing:** engine/library-level iOS work (rendering backend, audio backend, input, mobile
shim) → contribute to `Kenix3/libultraship` `port-maintenance`, likely collaborating with or building on
coco875's #1083 and the SpaghettiKart iOS precedent; app-shell/packaging/on-device-extraction/UI work → a
dedicated fork of `soh` for iOS, following the Android-fork and SpaghettiKart-iOS precedent, since nothing
like that has ever been accepted into the mainline SoH repo for *any* platform (Android included).

---

## PART B — LICENSING

### B1. Licenses of local trees (read in full)

| Repo (local path) | License file | License | Copyright holder |
|---|---|---|---|
| `soh` | **none found at repo root** (`find soh -iname "LICENSE*"` returns only `soh/soh/soh/Enhancements/randomizer/3drando/LICENSE.md`, a vendored subcomponent) | — | — |
| `lus` | `lus/LICENSE` | MIT | "kenix3 kenixwhisperwind@gmail.com," 2022 |
| `lus-pinned` (port-maintenance @ 2bfbde3) | `lus-pinned/LICENSE` | MIT | "kenix3 kenixwhisperwind@gmail.com," 2022 |
| `zapdtr` | `zapdtr/LICENSE` | MIT | "Zelda Reverse Engineering Team," 2020 |
| `otrexporter` | `otrexporter/LICENSE` | MIT | "Harbour Masters," 2022 |
| `lus-wiiu` | `lus-wiiu/LICENSE` | MIT | "kenix3 kenixwhisperwind@gmail.com," 2022 |

**Flag: `HarbourMasters/Shipwright` (the `soh` local tree) has no top-level `LICENSE` file at all.** This is
worth independently confirming against the live GitHub repo (it's possible one exists on GitHub but wasn't
pulled into this local checkout) — but as checked here, the SoH/Shipwright repo itself ships no explicit
license grant of its own code, unlike every one of its dependencies (LUS, ZAPDTR, OTRExporter), which are
all cleanly MIT. Practically: SoH's own source is presumably intended to be treated as source-available/
MIT-compatible given it links MIT libraries and openly distributes source, but the **absence of a LICENSE
file at the SoH repo root is a real gap** to resolve (ask upstream, or check the live GitHub repo directly)
before building a redistributable iOS product on top of it — you cannot currently point to an explicit
license grant text for the SoH-specific code layer.

**No GPL/LGPL/copyleft found anywhere in the license set reviewed.** All licenses found (own code + vendored
deps enumerated below) are MIT, BSD-3-Clause, Apache-2.0, or zlib — all permissive, all compatible with a
closed/App-Store-distributed binary.

### B2. Vendored dependency licenses (from `lus-pinned/README.md` dependency list, cross-referenced against
the pinned `port-maintenance@2bfbde3` tree)

| Dependency | License | Role |
|---|---|---|
| Fast3D | MIT | display-list renderer |
| prism-processor (KiritoDv) | MIT | shader preprocessor |
| ImGui | MIT | UI |
| SDL2 | **zlib** | windowing/input backend |
| glew | modified BSD-3-Clause / MIT | GL extension loading (Windows/macOS) |
| **metal-cpp** | **Apache-2.0** | Apple Metal backend (macOS/**iOS**) — confirmed used, `gfx_metal.cpp` is one of the 8 files in the tree with `__IOS__` guards |
| **StormLib** | **MIT** | `.mpq`/`.otr` archive read/write — confirms StormLib is MIT (not the older LGPL-era licensing some sources cite; the pinned tree's own README explicitly links StormLib's MIT LICENSE file) |
| zlib (StormLib's compression dep) | zlib | compression |
| bzip2 (StormLib's compression dep) | bzip2 license | compression |
| **libzip** | **BSD-3-Clause** | `.zip`/`.o2r` archive read/write |
| zlib (libzip's compression dep) | zlib | compression |
| StrHash64 | MIT, zlib, BSD-3-Clause (multi) | crc64 |
| nlohmann-json | MIT | JSON |
| spdlog | MIT | logging |
| {fmt} (spdlog's bundled dep) | MIT | text formatting |
| stb | MIT | image conversion |
| thread-pool (bshoshany) | MIT | resource-manager thread pool |
| tinyxml2 | zlib | XML parsing |

**Conclusion: every dependency actually used by the pinned `port-maintenance@2bfbde3` LUS tree is
permissively licensed (MIT/BSD-3-Clause/Apache-2.0/zlib/bzip2), with zero GPL/LGPL/AGPL exposure found.**
This directly confirms and updates the assumptions in the task brief: StormLib is MIT (verified from the
pinned tree's own dependency table, not just "after 9.0" — the currently pinned commit's docs assert MIT
outright with a link to StormLib's actual LICENSE file), libzip is BSD-3-Clause, spdlog/imgui/nlohmann are
MIT, metal-cpp is Apache-2.0 and is explicitly the macOS/iOS Metal backend, SDL2 and tinyxml2 are zlib.
Source (local): `lus-pinned/README.md` dependency list (bottom section); file-level confirmation via
`grep -rl __IOS__ lus-pinned/src lus-pinned/include` → includes `src/fast/backends/gfx_metal.cpp`.

### B3. Asset posture — exact stance, and what an iOS port must preserve

From `soh/README.md` (local, read in full), verbatim/near-verbatim citations:
- Line 16: **"The Ship does not include any copyrighted assets. You are required to provide a supported
  copy of the game."**
- Line 18–19: "Verify your ROM dump... using the compatibility checker at https://ship.equipment/... or...
  cross-reference its `sha1` hash with the hashes [here](docs/supportedHashes.json)."
- Line 77 (Project Overview): "In order for the game to function, you will require a **legally acquired**
  ROM for Ocarina of Time... **Any copyrighted assets are extracted from the ROM and reformatted as a `.o2r`
  archive file** which the code uses."
- Line 12: "Please keep in mind that we do not condone piracy."

**What an iOS port must preserve, directly derived from this stance and from A1/A3's precedent (Android
forks, SpaghettiKart iOS build)**:
1. **No ROM in the repo or the shipped app/ipa.** Never bundle Ocarina of Time ROM data anywhere in the
   build, binary, or App Store/TestFlight/AltStore artifact.
2. **No pre-generated `.o2r`/`.otr` in the repo or the app.** The archive must be generated *on-device from
   the user's own ROM* at first run — exactly the pattern both Android forks and the SpaghettiKart iOS build
   use (interactive/async extraction flow on first launch, `.otr`/`.o2r` cached locally afterward).
3. **No extracted/decoded assets checked into source control or bundled in the binary** — same constraint,
   restated for the intermediate representation, not just the ROM.
4. **User-supplied-only model end to end**: ROM import via the iOS Files app (SpaghettiKart iOS precedent),
   hash-verification against the existing `docs/supportedHashes.json` compatibility list before extraction,
   and the same "we do not condone piracy" posture carried into any iOS-specific onboarding UI/copy.

### B4. Factual precedent — DMCA/legal landscape (facts only, no outcome speculation)

- **No DMCA/takedown history found against SoH, HarbourMasters, or libultraship specifically.** Search
  turned up general awareness of legal risk in community discussion but no documented takedown notice,
  cease-and-desist, or lawsuit naming these projects. https://www.shipofharkinian.com/faq
- **Nintendo v. Tropic Haze (Yuzu), settled March 4, 2024**: $2.4M settlement, permanent injunction, Yuzu
  pulled off the market along with its source code, tied by Nintendo to the pre-release leak of *Tears of
  the Kingdom*. https://zeldauniverse.net/2024/03/06/emulator-company-yuzu-settles-nintendo-lawsuit-with-2-4-million-usd/
- **Ryujinx, October 2024**: no lawsuit — Nintendo pressured the maintainer (gdkchan) directly, resulting in
  the project and org being taken down out-of-court; Nintendo separately filed **DMCA takedowns against
  Ryujinx forks on GitHub** (also hitting Suyu, Sudachi, Citron, MeloNX).
  https://gbatemp.net/threads/nintendo-issues-dmca-takedown-notices-to-ryujinx-forks-on-github.667947/
- **zeldaret/oot decomp non-infringement stance**: the project's position is that decompiled code is
  independently reconstructed source that compiles to the same output, not copied code, and the repo ships
  **no game assets** — a prior legally-obtained ROM is required to build a working ROM/ports from it. Some
  outside legal commentary flags residual uncertainty specifically around use of leaked internal symbol
  tables/source, but no enforcement action against zeldaret itself was found.
  https://github.com/zeldaret/oot ; https://www.resetera.com/threads/zelda-64-ocarina-of-time-has-been-fully-decompiled-potentially-opening-the-door-for-mods-and-ports.520527/
- **Apple's April 2024 App Store rule change (guideline 4.7)**: Apple began permitting "retro game console
  emulator apps" globally; Delta (Riley Testut) shipped July 2024, downloaded ~3.8M times in two weeks per
  Appfigures, and later added iPad support and an External Purchase Link Entitlement for Patreon-based
  purchases (Dec 2024) instead of in-app purchase.
  https://www.macrumors.com/2024/04/17/what-to-know-about-iphone-app-store-emulators/ ;
  https://www.resetera.com/threads/the-verge-apple-opens-the-app-store-to-retro-game-emulators-up-delta-available-now-on-the-app-store.837237/
- **Most directly relevant App Store precedent — a ROM/game-data-requiring *port* (not an emulator) already
  ships on the App Store: ScummVM.** ScummVM is officially distributed on the App Store
  (https://apps.apple.com/us/app/scummvm/id6446184412), ships with only two freeware demo games bundled, and
  **requires the user to supply their own original game data files** (own CDs/floppies/GOG/Steam purchases)
  for everything else — architecturally identical in spirit to SoH/LUS (reimplemented engine + user-supplied
  original data, no emulation of a general-purpose CPU/OS). Reporting on its App Store approval specifically
  attributes it to ScummVM **not being classified as an emulator** ("does not allow running any program or
  code"), i.e. it was allowed under ordinary app review, independent of the 2024 guideline-4.7 emulator
  carve-out. This is a stronger and more directly applicable precedent for a SoH iOS port than the
  Delta/emulator precedent, since SoH is also an engine port requiring user-supplied original data rather
  than a general ROM emulator. Sources: https://apps.apple.com/us/app/scummvm/id6446184412 ;
  https://docs.scummvm.org/en/latest/other_platforms/ios.html ;
  https://www.resetera.com/threads/scummvm-is-released-officially-on-ios-ipados.800286/
- No evidence found either way of any *other* decomp/source-port project (OoT or otherwise) having
  specifically attempted and been rejected from, or accepted to, the App Store — ScummVM is the clearest
  analog found, not a direct SoH-category precedent.
- **Sideloading/distribution paths, 2025–2026 status**:
  - **TestFlight**: standard, low-friction beta distribution (still requires an Apple Developer account and
    Apple's review of the build, and caps at ~10,000 external testers / 90-day build expiry — general
    TestFlight mechanics, not SoH-specific).
  - **AltStore PAL**: EU-only (DMA-driven), co-created by Riley Testut (Delta's developer) — an officially
    Apple-sanctioned alternative marketplace requiring iOS/iPadOS 18.0+ and an EU/Japan/Brazil App Store
    account as of 2026. https://techcrunch.com/2026/02/22/move-over-apple-meet-the-alternative-app-stores-available-in-the-eu-and-elsewhere/
  - **SideStore**: open-source, no-jailbreak sideloading using just an Apple ID — notably, **SternXD (one of
    the two active current iOS contributors to `Kenix3/libultraship`, per A2) is SideStore's project
    maintainer**, per their public GitHub bio/profile activity. This is a direct, non-coincidental link
    between "who is doing the LUS iOS engine work" and "who maintains one of the leading iOS sideloading
    distribution tools" — worth factoring into any distribution-strategy conversation with that contributor.
  - EU DMA has forced Apple to permit third-party marketplaces/sideloading generally since 2024; outside the
    EU/Japan/Brazil, TestFlight and (jailbreak-free) SideStore-style signing remain the practical non-App-
    Store paths as of mid-2026.

---

## Key file paths referenced (local)

- `/tmp/claude-0/-home-user-harkinianpad/f6ff1f43-8b8f-5a94-b998-a5249c3653f5/scratchpad/soh/README.md`
- `/tmp/claude-0/-home-user-harkinianpad/f6ff1f43-8b8f-5a94-b998-a5249c3653f5/scratchpad/soh/CMakeLists.txt`
- `/tmp/claude-0/-home-user-harkinianpad/f6ff1f43-8b8f-5a94-b998-a5249c3653f5/scratchpad/soh/.gitmodules`
- `/tmp/claude-0/-home-user-harkinianpad/f6ff1f43-8b8f-5a94-b998-a5249c3653f5/scratchpad/lus-pinned/LICENSE`
- `/tmp/claude-0/-home-user-harkinianpad/f6ff1f43-8b8f-5a94-b998-a5249c3653f5/scratchpad/lus-pinned/README.md`
- `/tmp/claude-0/-home-user-harkinianpad/f6ff1f43-8b8f-5a94-b998-a5249c3653f5/scratchpad/lus-pinned/docs/PORTING.md`
- `/tmp/claude-0/-home-user-harkinianpad/f6ff1f43-8b8f-5a94-b998-a5249c3653f5/scratchpad/lus-pinned/src/ship/port/mobile/MobileImpl.cpp`
- `/tmp/claude-0/-home-user-harkinianpad/f6ff1f43-8b8f-5a94-b998-a5249c3653f5/scratchpad/lus-pinned/cmake/dependencies/ios.cmake`
- `/tmp/claude-0/-home-user-harkinianpad/f6ff1f43-8b8f-5a94-b998-a5249c3653f5/scratchpad/lus-wiiu/LICENSE`
- `/tmp/claude-0/-home-user-harkinianpad/f6ff1f43-8b8f-5a94-b998-a5249c3653f5/scratchpad/zapdtr/LICENSE`
- `/tmp/claude-0/-home-user-harkinianpad/f6ff1f43-8b8f-5a94-b998-a5249c3653f5/scratchpad/otrexporter/LICENSE`
