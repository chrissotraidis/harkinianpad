# 04 — Filesystem/Sandbox Behavior & On-Device Asset Extraction (SoH + LUS, iOS feasibility)

Trees examined (`SCRATCH` is used below only as a stable label for the
disposable investigation workspace):
- `SCRATCH/lus` — libultraship main (HEAD a3f1e102, 2026-06-12)
- `SCRATCH/lus-pinned` — libultraship at SoH's pinned commit (HEAD 2bfbde3a, 2026-07-21)
- `SCRATCH/soh` — Ship of Harkinian main
- `SCRATCH/zapdtr` — ZAPDTR
- `SCRATCH/otrexporter` — OTRExporter

**Headline finding:** the pinned libultraship ALREADY contains first-class iOS support: an `__IOS__` compile definition gated on `CMAKE_SYSTEM_NAME STREQUAL "iOS"` (`SCRATCH/lus-pinned/src/CMakeLists.txt:176-182`, plus Xcode bundle-ID/code-sign handling at `SCRATCH/lus-pinned/CMakeLists.txt:14,22,59,76`), iOS path logic in Context (below), Metal-backend iOS branches (`src/fast/backends/gfx_metal.cpp:66,1285`), SDL GL-ES/iOS branches (`src/fast/backends/gfx_sdl2.cpp:376`), a mobile virtual-keyboard shim (`src/ship/port/mobile/MobileImpl.cpp:1-26`), and iOS branches in `Fast3dWindow.cpp:77`, `Fast3dGui.cpp:23,61,73`, `StatsWindow.cpp:20`. The same exists in LUS main (`SCRATCH/lus/src/CMakeLists.txt:181`, `SCRATCH/lus/src/ship/Context.cpp:245,462,525`). SoH itself has almost no mobile ifdefs (only `SCRATCH/soh/soh/soh/Enhancements/debugger/SohStatsWindow.cpp:12`), so the iOS work is on the SoH layer, not LUS.

---

## A1. Filesystem map — every path read/written

### The path-resolution seam (libultraship `Ship::Context`)

Declared in `SCRATCH/lus-pinned/include/ship/Context.h:97-112`:
- `GetAppBundlePath()` — "install/read-only" dir
- `GetAppDirectoryPath(appName)` — "writable data" dir
- `GetPathRelativeToAppBundle(path)` / `GetPathRelativeToAppDirectory(path, appName)`
- `LocateFileAcrossAppDirs(path, appName)` — tries app dir, then bundle dir, then falls back to `"./" + path` (cwd)

Implementation `SCRATCH/lus-pinned/src/ship/Context.cpp`:

`GetAppBundlePath()` (lines 460-521):
- `__ANDROID__`: `SDL_AndroidGetExternalStoragePath()` (461-466)
- `__IOS__`: `getenv("HOME") + "/Documents"` (468-471) — **iOS already handled**
- `NON_PORTABLE`: `CMAKE_INSTALL_PREFIX` (473-474)
- `__APPLE__` (macOS): `FolderManager::getMainBundlePath()` = `[[NSBundle mainBundle] resourcePath]` (476-479; impl `SCRATCH/lus-pinned/src/ship/utils/AppleFolderManager.mm:35-38`)
- `__linux__`: directory of `/proc/self/exe` (481-495)
- `_WIN32`: directory of `GetModuleFileNameW` (497-517)
- fallback: `"."` (519)

`GetAppDirectoryPath(appName)` (lines 523-569):
- `__ANDROID__`: `SDL_AndroidGetExternalStoragePath()` (524-529)
- `__IOS__`: `getenv("HOME") + "/Documents"` (531-534) — i.e. the app-container Documents dir; **sandbox-legal**
- `__APPLE__` (macOS): `SHIP_HOME` env var, `~`-expanded; creates `~/Library/Application Support/<bundleid>` via `FolderManager::CreateAppSupportDirectory` (536-549; `AppleFolderManager.mm:21-33` uses `NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory)`). SoH's macOS bundle sets `SHIP_HOME=~/Library/Application Support/com.shipofharkinian.soh` via `LSEnvironment` (`SCRATCH/soh/soh/macosx/Info.plist.in:36-40`).
- `__linux__`: `SHIP_HOME` env (551-556)
- `NON_PORTABLE`: `SDL_GetPrefPath(NULL, shortName)` (558-566) — but `NON_PORTABLE` is OFF by default (`SCRATCH/lus-pinned/CMakeLists.txt:10`), so portable desktop builds fall through to…
- fallback: `"."` = **cwd, next to the executable** (568)

`GetPathRelativeToAppDirectory` (575-577), `GetPathRelativeToAppBundle` (571-573), `LocateFileAcrossAppDirs` (579-594; cwd fallback `"./"+path` at line 593).

### Concrete files, with the helper each goes through

| File | Purpose | Cite |
|---|---|---|
| `shipofharkinian.json` | config; passed as configFilePath | `SCRATCH/soh/soh/soh/OTRGlobals.cpp:279`; opened via `GetPathRelativeToAppDirectory` in `SCRATCH/lus-pinned/src/ship/Context.cpp:197` |
| CVars | persisted INSIDE the config json under `CVars.*` keys | `SCRATCH/lus-pinned/src/ship/config/ConsoleVariable.cpp:243-255` |
| `cvars.cfg` | legacy import only (read) | `SCRATCH/lus-pinned/src/ship/config/ConsoleVariable.cpp:340` |
| `logs/<Name>.log` | spdlog rotating file sink, 10 MB × 10 files | `SCRATCH/lus-pinned/src/ship/Context.cpp:167-168` |
| `imgui.ini`, `imgui_log.txt` | ImGui ini/log redirected into app dir | `SCRATCH/lus-pinned/src/ship/window/gui/Gui.cpp:79-80` |
| `default.sav` | LUS libultra EEPROM shim (not used by SoH's SaveManager) | `SCRATCH/lus-pinned/src/libultraship/libultra/os_eeprom.cpp:13,38` |
| `Save/file<N>.sav`, `Save/global.sav` | SoH saves; dir created on init; legacy `oot_save.sav` migration | `SCRATCH/soh/soh/soh/SaveManager.cpp:54-55,59-60,416-429` — but legacy converter reads bare relative `"oot_save.sav"` from **cwd** at `SaveManager.cpp:2732` |
| `oot.o2r` / `oot-mq.o2r` | game archives; located across app dirs | `SCRATCH/soh/soh/soh/OTRGlobals.cpp:790-797` |
| `soh.o2r` | port asset archive shipped with the game | `SCRATCH/soh/soh/soh/OTRGlobals.cpp:281` |
| `mods/` (+`custom_mod_files_go_here.txt`) | patches dir; default `GetAppDirectoryPath() + "/mods"` | `SCRATCH/lus-pinned/src/ship/Context.cpp:234`; created in `SCRATCH/soh/soh/soh/OTRGlobals.cpp:377-392`; listed by `SCRATCH/soh/soh/soh/Enhancements/mod_menu.cpp:213` |
| `gamecontrollerdb.txt` | read via `LocateFileAcrossAppDirs` and fed to `SDL_GameControllerAddMappingsFromFile` | `SCRATCH/lus-pinned/src/libultraship/libultra/os.cpp:18-19` |
| `Randomizer/` (spoiler/plando jsons) | created + written under app dir | `SCRATCH/soh/soh/soh/Enhancements/randomizer/3drando/spoiler_log.cpp:371-387`; `Plandomizer.cpp:366,575` |
| `presets/<name>.json` | preset save/load | `SCRATCH/soh/soh/soh/Enhancements/Presets/Presets.cpp:287,499` |
| `timesplitdata.json` | time splits | `SCRATCH/soh/soh/soh/Enhancements/timesplits/TimeSplits.cpp:364` |
| "Open App Files Folder" menu button uses `GetAppDirectoryPath()` | `SCRATCH/soh/soh/soh/SohGui/SohMenuSettings.cpp:198` |
| `Game.Main Archive` / `Game.Patches Archive` config keys can override archive dirs | `SCRATCH/lus-pinned/src/ship/Context.cpp:233-234` |

Screenshots: no screenshot-to-disk code exists in either SoH or pinned LUS (grep for `screenshot` case-insensitive matches only a controller-db log string, `ConnectedPhysicalDeviceManager.cpp:73`). Nothing to remap.

## A2. iOS-sandbox violations & containment

**How contained is it?** Very contained. Everything above flows through the four `Ship::Context` static helpers — one seam, `SCRATCH/lus-pinned/src/ship/Context.cpp:460-594`. And the seam **already has a correct iOS branch** (`HOME/Documents` for both bundle-path and app-dir, lines 468-471 and 531-534). Raw `fopen`/`std::ofstream`/`std::filesystem` calls in SoH (`SCRATCH/soh/soh/soh/`: OTRGlobals.cpp, SaveManager.cpp, randomizer files, Presets.cpp, TimeSplits.cpp, Extractor/Extract.cpp) almost always operate on strings produced by those helpers.

Deviations that would violate/misbehave under the iOS sandbox (or at least under a read-only bundle):

1. **cwd-relative fallbacks.** `LocateFileAcrossAppDirs` returns `"./"+path` if not found (Context.cpp:593); `GetAppBundlePath`/`GetAppDirectoryPath` return `"."` in the portable fallback (519, 568) — on iOS these are dead because the `__IOS__` branch returns first, but any code relying on cwd still needs care since iOS launches apps with cwd `/`.
2. `OTRGlobals::RunExtract` deletes **cwd-relative** `"oot.o2r"` / `"oot-mq.o2r"` when regen is needed (`SCRATCH/soh/soh/soh/OTRGlobals.cpp:450-451`) — wrong dir on iOS (and on macOS today, incidentally).
3. `SaveManager::ConvertFromUnversioned` opens cwd-relative `"oot_save.sav"` (`SaveManager.cpp:2732`) — legacy path, harmless if absent.
4. `Extractor::GetRoms` unix branch pushes bare `dir->d_name` (no directory prefix) and `stat`s it relative to cwd (`SCRATCH/soh/soh/soh/Extractor/Extract.cpp:247-269`) — only works when cwd == search path; broken/irrelevant on iOS; the `#else` `std::filesystem` branch (271-279) is the sane one.
5. `Extractor::CallZapd` **changes the process cwd** to a temp dir (`Extract.cpp:664`) and back (698). Legal on iOS (`NSTemporaryDirectory`/`std::filesystem::temp_directory_path` resolves inside the container, and `create_symlink` of the assets dir at line 661 works in-container), but cwd is process-global — game must not be concurrently reading relative paths. It uses `std::filesystem::temp_directory_path()` (Extract.cpp:621-636) which maps to `tmp/` in the app container — fine, Caches/tmp semantics apply.
6. Windows-only checks (`ES_WINDOWS`: writing `./text.txt`, `./test/` at `OTRGlobals.cpp:522-546`) are `_WIN32`-gated at the state machine entry (468-469) — not an iOS issue.
7. `RunExtract` requires `installPath + "/assets"` to exist (`OTRGlobals.cpp:441`), where `installPath = GetAppBundlePath()` (422). On iOS, `GetAppBundlePath()` returns **Documents**, not the .app bundle — so the 55 MB of extraction XMLs (see B3) must be copied/shipped into Documents on first run, or `GetAppBundlePath()` iOS branch changed to the real `[NSBundle mainBundle] resourcePath]` (which LUS already implements for macOS in `AppleFolderManager.mm:35-38`; note the file is compiled for `__APPLE__`, which includes iOS).

**Container-relative equivalents:** current `__IOS__` mapping puts *everything* (config, saves, logs, archives, mods) in `Documents/` — acceptable and user-visible via Files if `UIFileSharingEnabled`. A cleaner split would be: archives+mods in `Documents/`, config/saves in `Library/Application Support/` (via existing `FolderManager::pathForDirectory`, `AppleFolderManager.mm:40-50`), logs in `Library/Caches/` — all changeable at the single Context.cpp seam.

## A3. Archive discovery

- `Context::InitResourceManager` (`SCRATCH/lus-pinned/src/ship/Context.cpp:222-259`): main path = config `Game.Main Archive` defaulting to `GetAppDirectoryPath()`; patches path = `Game.Patches Archive` defaulting to `<appdir>/mods` (233-234). If explicit `archivePaths` are passed, those are used instead (242-245). If nothing loads and `allowEmptyPaths==false`, shows "OTR file not found" SDL box; **there is already an `#ifdef __IOS__ exit(0)` for this dialog** (247-256).
- `ArchiveManager::Init → GetArchiveListInPaths` (`SCRATCH/lus-pinned/src/ship/resource/archive/ArchiveManager.cpp:205-236`): for each path, if it's a directory, scans (non-recursively) for `.otr/.zip/.mpq/.o2r` (212-220); regular files are added directly (225-226). `AddArchive` picks O2R (libzip) for `.o2r/.zip`, OtrArchive (StormLib MPQ, only `#ifdef INCLUDE_MPQ_SUPPORT`) for `.otr/.mpq`, FolderArchive for extension-less paths (238-257).
- SoH passes archives explicitly: `InitResourceManager({ portArchivePath /*soh.o2r*/ }, {}, 3, /*allowEmptyPaths=*/true)` (`SCRATCH/soh/soh/soh/OTRGlobals.cpp:303`), then after the extract step `OTRGlobals::Initialize()` adds `oot-mq.o2r`/`oot.o2r` found via `LocateFileAcrossAppDirs` (`OTRGlobals.cpp:790-797`). Game-version CRCs are validated against `ValidHashes` (`OTRGlobals.cpp:799` onwards; mismatch → error box + exit at ~`OTRGlobals.cpp:944-955`).

**Files-picker import: yes, sufficient.** On iOS `GetAppDirectoryPath()` = `Documents/`; dropping `oot.o2r`/`soh.o2r` into the app's Documents (Files app with `UIFileSharingEnabled`, or `UIDocumentPickerViewController` + copy into container) is exactly where `LocateFileAcrossAppDirs` looks first (Context.cpp:582-586). No code change needed for discovery; only the first-run UX.

---

## B1. Desktop extraction pipeline & how ZAPD is invoked

Boot: `main()` (`SCRATCH/soh/soh/src/code/main.c:59`) → `InitOTR(argc, argv)` (main.c:62) → `OTRGlobals` ctor (context + soh.o2r + window init, `OTRGlobals.cpp:278-335`) → `OTRGlobals::Instance->RunExtract(argc, argv)` (`OTRGlobals.cpp:1527-1529`) → `OTRGlobals::Initialize()` (1531).

`RunExtract` (`OTRGlobals.cpp:398-772`) is an ImGui-driven state machine (ES_PORT_ARCHIVE → ES_WINDOWS(win only) → ES_EXTRACT/ES_EXTRACT_ARGS → ES_VERIFY) that renders in-window popups and a progress bar (render loop lines 709-764, progress modal 737-760). Extraction is submitted to a 1-thread `BS::thread_pool` (line 454) via `extract.CallZapd(...)` (596, 603, 658, 676).

**ZAPD is a statically linked library, called in-process — NOT a spawned process.**
- `Extractor::CallZapd` (`SCRATCH/soh/soh/soh/Extractor/Extract.cpp:641-702`) builds a 22-element fake `argv` (`"ZAPD" "ed" -i assets/xml/<ver> -b <rom> -fl assets/filelists -rconf assets/Config_<ver>.xml -se OTR --otrfile oot(-mq).o2r --portVer x.y.z ...`, lines 670-691) and calls `zapd_report(argc, argv, extractCount, totalExtract)` directly (line 693; extern decl at 638).
- `zapd_report` is ZAPDTR's real entry point: `SCRATCH/zapdtr/ZAPD/Main.cpp:145-235`; the standalone CLI is just a wrapper (`SCRATCH/zapdtr/ZAPD/ExecutableMain.cpp:5-9`, `Main.cpp:237-239` `zapd_main`).
- Build: `add_library(${PROJECT_NAME} STATIC ...)` = ZAPDLib (`SCRATCH/zapdtr/ZAPD/CMakeLists.txt:263`) vs `add_executable(ZAPD ExecutableMain.cpp)` (:265). SoH links `ZAPDLib` (`SCRATCH/soh/soh/CMakeLists.txt:624,642,662,704`; subdir added at 107-108). The ZAPD *executable* is used only at build time to create `soh.o2r` (`SCRATCH/soh/CMakeLists.txt:230,241`).
- The exporter side is registered in-process too: `ImportExporters()` installs OTRExporter callbacks (`SCRATCH/otrexporter/OTRExporter/Main.cpp:396-440`); `ExporterProgramEnd` writes the final archive (Main.cpp:93-272).

Mechanics of one run (`Extract.cpp:641-702`): make temp dir (`Mkdtemp`, 621-636), symlink `installPath/assets` into it (661; copy on Windows 657-659), `chdir` there (664), run zapd in-process (693), copy resulting `oot(-mq).o2r` into the app dir (695), `chdir` back and delete temp dir (698-699).

## B2. ROM detection & threading

- Supported versions by header CRC: 15 constants `OOT_PAL_GC … OOT_NTSC_12` (`SCRATCH/soh/soh/soh/Extractor/Extract.cpp:54-68`), human names in `verMap` (70-79). Full-ROM CRC32C whitelist of 21 known-good dumps `goodCrcs` (82-104), checked in `ValidateAndFixRom` (341-355; also re-patches the MQ-debug header byte at 343-345). Size must be exactly 32/54/64 MB (`ValidateRomSize`, 376-381; constants `Extract.h:18-21`). Compression sniffing rejects zip/rar/7z (358-374). MQ detection by version CRC (`IsMasterQuest`, 561-582); CRC→ZAPD version string map (`GetZapdVerStr`, 584-619). ZAPDTR re-detects version + DMA-table offset in `ZRom` (`SCRATCH/zapdtr/ZAPD/ZRom.cpp:116-247`).
- Threading: ZAPDTR *has* a `ctpl::thread_pool` sized `hardware_concurrency()/2` (`SCRATCH/zapdtr/ZAPD/Main.cpp:661-662`) **but immediately forces `Globals::Instance->singleThreaded = true` (Main.cpp:668)**, so the per-file loop runs sequentially on the calling thread (680-686); the pool branch (688-693) is dead code in the `ed` mode SoH uses. SoH runs the whole thing on one background worker (`BS::thread_pool(1)`, `OTRGlobals.cpp:454`). Net: extraction is effectively single-threaded — good for iOS predictability, slower wall-clock.

## B3. Desktop-only dependencies / iOS blockers

- **No process spawning in the extraction path itself** — `zapd_report` is a function call (B1). No fork/exec/CreateProcess in Extract.cpp/ZAPDTR Main.cpp.
- **UI is the real blocker:** the ROM chooser uses portable-file-dialogs `pfd::open_file` (`Extract.cpp:321`), which on POSIX works by `popen()`-ing zenity/kdialog/osascript (`SCRATCH/soh/soh/soh/Extractor/portable-file-dialogs.h:33,40,493-522,551-563`) — nonexistent on iOS. All the `SDL_ShowMessageBox`/`MessageBoxA` prompts (`Extract.cpp:112-189`) are also unusable/ugly on iOS. Replacement: `UIDocumentPickerViewController` for the ROM + the existing ImGui popup flow in `RunExtract` (which is already windowed ImGui, not native dialogs — only `ManuallySearchForRom`/message boxes need replacing).
- **External asset descriptions:** extraction needs `assets/xml/<version>/*.xml` (~55 MB in-tree at `SCRATCH/soh/soh/assets/xml`), `assets/Config_<ver>.xml` + `assets/filelists/*.txt` + `version_info` (312 KB at `SCRATCH/soh/soh/assets/extractor`; filelists e.g. `gamecube_pal.txt`). On desktop these are copied next to the executable post-build (`SCRATCH/soh/soh/CMakeLists.txt:606-615`). On iOS: ship in the .app bundle and either point the tempdir symlink at the bundle path or copy once to the container (see A2 item 7).
- **Temp dir + symlink + chdir** (`Extract.cpp:655-664`): all legal inside the iOS container (symlink(2) works in-container; chdir is allowed). Only caveat is cwd being process-global.
- **No memory-mapped files** anywhere in the pipeline (no mmap/MapViewOfFile in Extract.cpp/ZAPDTR/OTRExporter).
- Libraries needed on iOS: tinyxml2, libzip (O2R), yaz0 — all portable; StormLib only if `.otr` MPQ support is kept (`ArchiveManager.cpp:247-250` makes it optional via `INCLUDE_MPQ_SUPPORT`).
- Verdict: **compiles and runs in-process on iOS in principle**; the work items are (a) ROM picker/dialog replacement, (b) assets-dir location fix, (c) memory headroom (B5).

## B4. ANDROID handling in-tree

No Android-specific extraction code exists in the SoH tree: grepping `ANDROID` across `SCRATCH/soh` matches nothing in soh code (the only mobile ifdef in SoH is `__IOS__` in `SohStatsWindow.cpp:12`). Android ifdefs exist only inside pinned LUS (`SCRATCH/lus-pinned/src/ship/Context.cpp:461-466,524-529` `SDL_AndroidGetExternalStoragePath`, `Fast3dWindow.cpp:77`, `Fast3dGui.cpp:23,61,73`, `MobileImpl.cpp:1`). How Android forks of SoH handle on-device extraction is **not answerable from these trees** — deferred to the agent researching the Android forks.

## B5. Memory/time cost (ESTIMATE — basis cited)

What the code demonstrably allocates during one extraction:
1. `Extractor::mRomData` — fixed 64 MB buffer, allocated for the object's lifetime (`SCRATCH/soh/soh/soh/Extractor/Extract.h:30`), whole ROM read into it (`Extract.cpp:211,414,472,524`).
2. `ZRom` — reads the **entire ROM again** into a vector (`SCRATCH/zapdtr/ZAPD/ZRom.cpp:119`) and then yaz0-decompresses **every DMA file into an in-memory map** `files` (ZRom.cpp:253-319). For a 32 MB retail ROM the decompressed total is roughly 40-55 MB; a 54/64 MB debug ROM is stored uncompressed, so ~54-64 MB, plus the ROM copy itself (32-64 MB).
3. OTRExporter in `ed` mode buffers **every converted resource in RAM**: `std::map<std::string, std::vector<char>> files` (`SCRATCH/otrexporter/OTRExporter/Main.cpp:46`, filled at Main.cpp:356-360 / 385-394); nothing is streamed to disk until `ExporterProgramEnd`.
4. `ExporterProgramEnd` reads the whole ROM a **third** time for the CRC (`Main.cpp:131-136`), then adds every buffered file to a libzip archive via `zip_source_buffer` (`SCRATCH/otrexporter/OTRExporter/ExporterArchiveO2R.cpp:73-93`). libzip defers compression/writing until `zip_close` (`ExporterArchiveO2R.cpp:34-50`; comment at `Main.cpp:270` confirms sources must stay valid until close), so the source buffers AND the zip's working set coexist at close time.

**Estimate (labeled as such):** peak ≈ 64 MB (Extractor buffer) + 32-64 MB (ZRom rom copy) + ~50-65 MB (ZRom decompressed file map) + ~100-200 MB (converted resource map; the shipped oot.o2r is on the order of 100+ MB and these buffers are its uncompressed inputs) + ROM re-read + libzip overhead ⇒ **roughly 350-550 MB peak RSS**, transiently, on the single extraction worker thread. Basis: the four allocation sites above; no measurements taken. That fits within iOS jetsam limits on any A12+ device (~2 GB+ for foreground apps) but is worth doing before the full game heap is up — which is exactly the current ordering (`RunExtract` happens before `Initialize()`/game heaps, `OTRGlobals.cpp:1527-1531`; SoH's game heap alloc happens later via `Heaps_Alloc()`, `main.c:67`). Time: single-threaded (B2); ZAPDTR prints "Generated OTR File Data in %i seconds" (`Main.cpp:710`) — desktop runs are minutes-order; expect longer on mobile but bounded.

## First-run flow when no archive exists (iOS-relevant)

`RunExtract` (`OTRGlobals.cpp:398-772`), reached unconditionally from `InitOTR` (1527-1529):
1. `soh.o2r` missing/outdated → in-window popup "Missing soh.o2r"/"soh.o2r is outdated" → exit (486-492).
2. Extraction `assets/` missing next to bundle → popup "Extractor assets not found" → exit (441-445).
3. Outdated `oot(-mq).o2r` (portVersion major mismatch — `DetectOTRVersion`/`VerifyArchiveVersion` at 1507-1517/1523-1525, version read from archive's `portVersion` entry) → popup + delete + regenerate (446-452).
4. No `oot.o2r`/`oot-mq.o2r` anywhere (`LocateFileAcrossAppDirs` checks at 620-624) → popup "No O2R files found. Generate one now?" (626-629) → scans bundle dir + app dir for `*.z64/.n64/.v64` (635-640, `Extract.cpp:229-280`) → offers found ROMs, else native file dialog (652-656 → `Extract.cpp:401-423`) → CallZapd on the 1-thread pool with ImGui progress modal (657-664, 727-761) → optional second (MQ/vanilla) extraction (667-686) → ES_VERIFY: if still no archive, popup "No ROM Archives … relaunch" and exit (692-704).

This whole flow renders through ImGui popups inside the game window (`SohGui::RegisterPopup`) — portable to iOS as-is — except the native pieces: `pfd`/SDL message-box ROM search (B3) and the `exit(0/1)` UX pattern (an iOS app should present in-app guidance instead of exiting; note LUS already special-cases `__IOS__ exit(0)` after its own missing-OTR dialog, `Context.cpp:251-254`).

## Notable version skew (pinned LUS vs LUS main)

Pinned LUS and main differ structurally (`Context::mContext` unique_ptr vs weak_ptr, `CreateInstance` signature, logging shutdown — see diff of `src/ship/Context.cpp` between the two trees), but both carry the same iOS path logic and `__IOS__` build support; feasibility conclusions hold on either.
