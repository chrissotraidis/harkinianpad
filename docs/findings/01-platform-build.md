# iOS/iPadOS Platform Feasibility for Ship of Harkinian — Findings

Trees examined:
- `lus` = libultraship main (shallow, 1 commit, HEAD `a3f1e10`)
- `lus-pinned` = libultraship @ `2bfbde3` (port-maintenance branch, 47 commits fetched) — **this is what SoH actually pins as a submodule**
- `soh` = Shipwright/SoH main
- `lus-wiiu` = HarbourMasters/libultraship-wiiu (dedicated console fork, HEAD `0622ac4`)

All line numbers verified by direct read on 2026-07-25. Unless stated otherwise, "LUS" findings below refer to **lus-pinned** since that is the version actually shipped in SoH.

---

# PART A — Platform Abstraction

## A.1 Architecture seams & full `__IOS__`/`__ANDROID__` inventory (lus-pinned)

**Layering:** `Ship::Window` (abstract, `lus-pinned/include/ship/window/Window.h`) → `Fast::Fast3dWindow` (`lus-pinned/src/fast/Fast3dWindow.cpp`) owns an `Interpreter` (`fast/interpreter.h`) that binds one `GfxWindowManagerApi` + one `GfxRenderingAPI` backend pair, selected at runtime from a compile-time-available set. There is exactly one concrete `Window` subclass (`Fast3dWindow`); no platform gets its own `Window` subclass — platform differences live inside the backend/GUI layer, not the class hierarchy.

**Backend registration** (`lus-pinned/src/fast/Fast3dWindow.cpp:24-40`, `Fast3dWindow` ctor):
```
#ifdef _WIN32       -> AddAvailableWindowBackend(FAST3D_DXGI_DX11)
#ifdef __APPLE__     -> if (Metal_IsSupported()) AddAvailableWindowBackend(FAST3D_SDL_METAL)
(always)            -> AddAvailableWindowBackend(FAST3D_SDL_OPENGL)
```
`__APPLE__` covers iOS too, so Metal is offered there. OpenGL is unconditionally *offered* here, but is compiled out for iOS at the CMake level (see A.1/B.1), so on iOS only Metal is actually selectable — the runtime list-building code doesn't know that (harmless because `ENABLE_OPENGL` guards the whole `.cpp`, see below, but is a latent trap if someone adds an iOS OpenGL-ES path later, since this ctor never gets an `#ifndef __IOS__` guard around the OpenGL line).

**`InitWindowManager()` switch** (`Fast3dWindow.cpp:136-162`) is guarded per-case by `#ifdef ENABLE_DX11` / `#ifdef ENABLE_OPENGL` / `#ifdef __APPLE__` (Metal case, `154`) — consistent with the ctor.

### Full `__IOS__` inventory (lus-pinned)
| File:Line | What it does |
|---|---|
| `src/CMakeLists.txt:181` | Defines the `__IOS__` compile macro, gated on `CMAKE_SYSTEM_NAME STREQUAL "iOS"` (full context `176-213`, see B.1) |
| `src/ship/window/gui/StatsWindow.cpp:20` | `elif defined(__IOS__)` → stats overlay prints "Platform: iOS" |
| `src/ship/port/mobile/MobileImpl.cpp:1` | `#if defined(__ANDROID__) \|\| defined(__IOS__)` — whole file: virtual-keyboard show/hide (`SDL_StartTextInput`/`SDL_StopTextInput`) driven by ImGui's `WantTextInput` |
| `src/ship/Context.cpp:251-254` | `InitResourceManager`: if the main OTR/O2R archive isn't found, iOS additionally calls `exit(0)` after the message box (no dialog-driven retry on iOS) |
| `src/ship/Context.cpp:468-471` | `GetAppBundlePath()`: on iOS returns `$HOME/Documents` (before the generic `__APPLE__`/`NON_PORTABLE` branches) |
| `src/ship/Context.cpp:531-534` | `GetAppDirectoryPath()`: same `$HOME/Documents` shortcut for iOS |
| `src/fast/Fast3dGui.cpp:23,61,73` | `SupportsViewports()` returns `false` for iOS/Android (no ImGui multi-viewport OS windows); `HandleWindowEvents` routes touch→ImGui via `Ship::Mobile::ImGuiProcessEvent` |
| `src/fast/backends/gfx_sdl2.cpp:376-379` | Window creation flags: iOS gets `SDL_WINDOW_BORDERLESS \| SDL_WINDOW_SHOWN` instead of `SDL_WINDOW_SHOWN \| SDL_WINDOW_RESIZABLE \| SDL_WINDOW_ALLOW_HIGHDPI` — i.e. resizing/HiDPI-toggle already stripped out for iOS |
| `src/fast/backends/gfx_metal.cpp:66-72` | `NonUniformThreadGroupSupported()`: iOS assumes `MTL::GPUFamilyApple4` (A11+) instead of querying `MTLCopyAllDevices` |
| `src/fast/backends/gfx_metal.cpp:1285-1294` | `Metal_IsSupported()`: hardcoded `return true` on iOS (`MTLCopyAllDevices` isn't available there) |

### Full `__ANDROID__` inventory (lus-pinned)
| File:Line | What it does |
|---|---|
| `src/ship/debug/CrashHandler.cpp:75,418` | Linux crash-handler (backtrace/signal) code explicitly excluded on Android (`__linux__ && !__ANDROID__`) — no Android/iOS equivalent crash handler exists at all |
| `src/ship/scripting/ScriptLoader.cpp:60` (`GetPlatform()`, `35-70`) | TCC scripting target-triple string: returns `"android"`, `"ios"` (via `TARGET_OS_IPHONE`, line 54), `"darwin"`, `windows_*`, `linux_*` — this is real, already-existing mobile support for SoH's C-mod scripting system |
| `src/ship/window/gui/Gui.cpp:73-77` | ImGui style/font scale ×2 for `__ANDROID__` only — **no `__IOS__` branch**, see A.5 gap |
| `src/ship/window/gui/GameOverlay.cpp:240-249` | Notification text width/offset doubled for Android only, same gap pattern as above |
| `src/ship/port/mobile/MobileImpl.cpp`, `Fast3dGui.cpp`, `Fast3dWindow.cpp:77-79` | Shared with iOS (see table above); `Fast3dWindow.cpp:77-79` forces `gameMode = true` (fullscreen-by-default sizing) for both |

## A.2 `src/ship/port/mobile/` — contents and completeness

Entire directory (`lus-pinned`):
- `src/ship/port/mobile/MobileImpl.cpp` (26 lines, full text read)
- `include/ship/port/mobile/MobileImpl.h`

That's the **entire** mobile port surface. It implements exactly one function, `Ship::Mobile::ImGuiProcessEvent(bool wantsTextInput)`, which starts/stops SDL text input to show/hide the on-screen keyboard for ImGui text fields. There is:
- no lifecycle handling (background/foreground/terminate/low-memory),
- no touch-to-gamepad virtual controller,
- no orientation handling,
- no safe-area/notch handling,
- no haptics,
- no App Store / permissions plumbing.

Compare to the Wii U fork's `WiiUImpl.cpp` (218 lines: filesystem bootstrap, UDP log redirection, VPAD/KPAD polling, abort-trap override) — the mobile shim is roughly 1/10th the size and covers a much narrower slice (only the soft-keyboard problem, which desktop platforms don't have).

## A.3 lus main vs lus-pinned — iOS support comparison

**They are functionally identical for iOS.** Every `__IOS__`/`__ANDROID__`/`CMAKE_SYSTEM_NAME STREQUAL "iOS"` hit in lus-pinned exists in lus main at the same or near-identical line numbers (confirmed via parallel grep: `lus/src/CMakeLists.txt:181`, `lus/src/ship/Context.cpp:245/462/525`, `lus/src/fast/Fast3dWindow.cpp:77`, `lus/src/fast/backends/gfx_sdl2.cpp:374`, `lus/src/fast/backends/gfx_metal.cpp:64/1283`, `lus/src/fast/Fast3dGui.cpp:23/61/74`, `lus/src/ship/port/mobile/MobileImpl.cpp:1`, `lus/src/ship/window/gui/StatsWindow.cpp:20`).

`diff -rq lus lus-pinned` shows ~80 files differing, but spot-checking (`diff lus/src/ship/window/gui/Gui.cpp lus-pinned/src/ship/window/gui/Gui.cpp`) shows the diffs are a mechanical `Context::GetInstance()` → `Context::GetRawInstance()` rename across the codebase (main is ahead by an API refactor), **not** iOS-related work. Line counts match exactly (398/398 for `Gui.cpp`).

Git log evidence is weak because both clones are shallow (`lus` = 1 commit only, `lus-pinned` = 47 commits on port-maintenance); `git log --oneline -- cmake/dependencies/ios.cmake` returns a single hit in each tree (`lus-pinned`: `5cb82fa Add PrismProcessor for Dynamic Shader Loading` — an incidental touch, not iOS-specific; `lus`: `a3f1e10 fix windows arm CI failure`, also incidental) — not deep enough to prove ordering, but consistent with "no divergence in iOS work between branches."

**Conclusion:** SoH is not leaving iOS support on the table by pinning to `2bfbde3` instead of tracking main — both have the same (self-declared, partially-broken — see gaps below) iOS scaffolding.

## A.4 Wii U fork — what it added, and the minimum surface a new platform implies

`lus-wiiu` (`HarbourMasters/libultraship-wiiu`) is forked from a **much older** pre-refactor LUS layout (`src/graphic/Fast3D/`, `src/public/bridge/`, no `src/ship`/`src/fast` split — confirmed via `find src -maxdepth 2 -type d` and a full path diff against lus-pinned), so it predates the current architecture and can't be diffed line-for-line against lus-pinned. Structurally, on top of base LUS it adds:

- `src/port/wiiu/WiiUImpl.{h,cpp}` (218 lines) — filesystem bootstrap (`mkdir`/`chdir` into `/vol/external01/wiiu/apps/<name>/`), UDP log redirection (`WHBLogUdpInit`), a custom `devoptab_t` to route `stdout`/`stderr` to `OSReport`, an `abort()` override that triggers a debugger trap for stack traces, and `VPADStatus`/`KPADStatus` polling wrappers exposed to the app (`include/.../WiiUImpl.h`).
- `src/port/wiiu/ImGui/imgui_impl_gx2.{h,cpp}` + `imgui_impl_wiiu.{h,cpp}` + hand-written GX2 shaders (`shaders/shader.{vsh,psh,h}`, `build-shaders.sh`) — a **complete bespoke rendering backend and ImGui backend**, because GX2 has no SDL/Metal/OpenGL equivalent library to lean on.
- `cmake/dependencies/wiiu.cmake` + patches: `patches/spdlog-wiiu.patch` and `patches/threadpool-wiiu.patch` strip `thread_local` usage (devkitPPC's toolchain doesn't support TLS), plus an `__wrap_abort` linker trick.

**Implication for a new platform:** the *minimum* surface a platform port needs is (1) a rendering backend + window-manager pair if no existing SDL2 backend fits (Wii U needed a from-scratch one; iOS does not — it reuses `GfxWindowBackendSDL2` + `GfxRenderingAPIMetal`, already wired), (2) an input-polling shim analogous to `WiiUImpl`'s VPAD/KPAD calls (iOS's `MobileImpl.cpp` does **not** provide this — it only does soft-keyboard toggling, see A.2), (3) filesystem/logging bootstrap for the sandboxed environment, (4) toolchain-specific dependency patches (Wii U needed `thread_local` patches; iOS doesn't need these since Apple Clang supports TLS, but does need code-signing/bundling accommodations, which LUS already has, see B.1), (5) a packaging/output step (Wii U: `wut_create_rpx`/`wut_create_wuhb`; iOS needs an Xcode `.app`/`.ipa` equivalent — **absent**, see B.4). iOS is structurally closer to "reuse an existing backend" than Wii U's "build one from scratch," which is the main reason iOS support looks further along in LUS than it actually functions (see gap list).

## A.5 Desktop-assumption leaks that would bite iOS

1. **Font/UI scaling for Retina displays is missing.** `src/ship/window/gui/Gui.cpp:73-77` doubles ImGui font/style scale only `#if defined(__ANDROID__)`; iOS is not in the condition. On an iPhone/iPad Retina display this leaves ImGui text render at desktop pixel density (effectively unreadably small on a phone). Same pattern in `src/ship/window/gui/GameOverlay.cpp:240` (notification text sizing, Android-only).
2. **No app-lifecycle (background/foreground/low-memory) handling.** `src/fast/backends/gfx_sdl2.cpp` `HandleSingleEvent` (`605-664`) switches on `SDL_KEYDOWN/UP`, `SDL_MOUSEBUTTONDOWN/UP`, `SDL_MOUSEWHEEL`, `SDL_WINDOWEVENT` (`639-656`), `SDL_DROPFILE`, `SDL_QUIT` (`660-662`) — there is **no** case for `SDL_APP_WILLENTERBACKGROUND` / `SDL_APP_DIDENTERBACKGROUND` / `SDL_APP_WILLENTERFOREGROUND` / `SDL_APP_DIDENTERFOREGROUND` / `SDL_APP_LOWMEMORY` / `SDL_APP_TERMINATING`, all of which SDL2 dispatches on iOS. Without handling these, the render/audio loop keeps running while backgrounded (battery drain, App Review rejection risk, iOS watchdog can kill the process) and there's no low-memory cache-trim hook.
3. **The game loop is a blocking native OS thread, not a UIKit-run-loop citizen.** SoH's `Main()` (`soh/soh/src/code/main.c:74-159`) spins up `Graph_ThreadEntry` via `osCreateThread`/`osStartThread` (mapped to a real pthread) and blocks in an `osRecvMesg` loop forever — this is the classic desktop/console "own the thread" model, which conflicts with iOS's expectation that apps yield to the run loop and respond promptly to suspend notifications (point 2 makes this worse: nothing currently tells that thread to pause).
4. **`main()` ownership**: no `int main`/`SDL_main`/`WinMain` exists anywhere in `lus-pinned` (`grep -rn "int main("` on `src`/`include` is empty) — LUS is a pure library; the entry point is 100% SoH's responsibility (`soh/soh/src/code/main.c:46-72`). That file defines `SDL_main` only under `#ifdef _WIN32` and a raw `int main(...)` otherwise (`main.c:46,59`). SDL2 on iOS normally requires the entry symbol to be `SDL_main` (SDL's `SDL_main.h` `#define`s `main` to `SDL_main` on mobile/console targets when `SDL_MAIN_NEEDED`/`SDL_MAIN_AVAILABLE` is set, and SDL supplies its own `UIApplicationMain`-based launcher). Whether `main.c`'s raw `int main` picks up that macro rewrite automatically depends on whether `SDL.h`/`SDL_main.h` is transitively included ahead of this definition — **unverified**, worth an explicit smoke test; if not, iOS will fail to link/launch until `main.c` is changed to always define `SDL_main` (mirroring the existing Windows branch) rather than gating it on `_WIN32`.
5. **Single-window, single-display assumptions**: `SupportsViewports()` correctly returns `false` for iOS (`Fast3dGui.cpp:61`), and the window is `SDL_WINDOW_BORDERLESS` (`gfx_sdl2.cpp:377`), so multi-window/multi-monitor isn't attempted — this one is already handled correctly, not a gap, but worth noting as evidence the team was aware of the issue class.
6. **Mouse cursor / cursor-visibility API exists but is a no-op concept on iOS** (`Window::SetCursorVisibility`, `include/ship/window/Window.h:96`; implemented in `Fast3dWindow::SetCursorVisibility` → `mWindowManagerApi->SetCursorVisibility`, `Fast3dWindow.cpp:225-227`) — not broken, just dead weight; no gap, but the whole mouse-capture/cursor-lock subsystem (`Window::GetMouseStateManager()`, used pervasively in `Gui.cpp:215-216`) assumes a pointer device exists, which iOS (no external mouse) mostly doesn't have.

## A.6 SoH-side platform code SoH itself carries (must be replicated for iOS)

**iOS presence in SoH today is almost nil:** `grep -rl __IOS__ soh/soh soh/src` → **one** hit, `soh/soh/Enhancements/debugger/SohStatsWindow.cpp:12` (mirrors LUS's `StatsWindow.cpp`, just prints "iOS" in the debug overlay). `__ANDROID__` → **zero** hits anywhere in `soh/soh` or `soh/src`.

By contrast, SoH carries **substantial** per-platform logic for the two console ports it does support, gated on `__SWITCH__`/`__WIIU__` (9 and 11 files respectively) and `__APPLE__` (9 files, mostly macOS bundle-path/menu quirks) and `_WIN32` (9 files). Representative examples an iOS port would need to mirror:
- `soh/soh/OTRGlobals.cpp`: platform-specific include of `<port/switch/SwitchImpl.h>` / `<port/wiiu/WiiUImpl.h>` (`58-74`); skips the desktop `Extractor/Extract.h` asset-extraction UI entirely on console (`58-59`, `457-458`, since assets ship pre-packaged); different "outdated/missing ROM" fatal-error UX per platform (`426-481`, e.g. `OSFatal()` call on Wii U, `942-944`).
- `soh/soh/SaveManager.cpp`: uses `copy_file` + `remove` instead of `std::filesystem::rename` for renaming stale save files on console (`514-517`, some console filesystems don't support atomic rename across the sandbox boundary) — 6 total `__SWITCH__`/`__WIIU__` sites (`514,1114,1192,1203,1327,2405`).
- `soh/soh/SohGui/ResolutionEditor.cpp:235`: exposes an "ignore aspect correction / stretch to fill" option only on console (fixed TV resolutions) — the same reasoning (fixed device screen, no arbitrary window resize) applies to a phone/tablet.
- `soh/soh/Enhancements/FileSelectEnhancements.cpp:45-59`: removes "or drop a spoiler log on the game window" hint text on console (no drag-and-drop) — directly applicable to iOS, which also has no drag/drop onto the window in the same sense.
- `soh/soh/Enhancements/bootcommands.c:13`, `soh/soh/ShipUtils.cpp:119`, `soh/soh/SohGui/SohMenuSettings.cpp:140/363`, `soh/soh/SohGui/Menu.cpp:798`, `soh/soh/Enhancements/controls/InputViewer.cpp:158`, `soh/soh/Enhancements/controls/SohInputEditorWindow.cpp:11`, `soh/soh/Enhancements/randomizer/randomizer_check_tracker.cpp:1069`: further console-specific UI/behavior toggles (input viewer layout, settings menu items disabled/renamed, boot-time argv handling) that would each need an iOS-aware branch or an explicit decision to treat iOS like console for that toggle.

**Also notable — no dedicated platform directories in SoH itself**: `soh/macosx/` exists (bundle icon + `Info.plist.in`, macOS-only), and `scripts/switch/build.sh` / `scripts/wiiu/build.sh` exist at the repo root as thin CI build-invocation scripts (not full platform source trees — those presumably live in separate SoH forks mirroring the `lus-wiiu` pattern). **No `soh/ios/` directory, no iOS Info.plist, no iOS build script exist anywhere in this repo.**

---

# PART B — Build System

## B.1 LUS CMake structure

**Top-level `lus-pinned/CMakeLists.txt`** (89 lines, full read):
- `cmake_minimum_required(VERSION 3.24.0)` (`:1`)
- iOS-specific options declared up front: `option(SIGN_LIBRARY "Enable xcode signing" OFF)` and `option(BUNDLE_ID ... "com.example.libultraship")`, gated on `CMAKE_SYSTEM_NAME STREQUAL "iOS"` (`:14-18`)
- `enable_language(OBJCXX)` + forces ARC flags for `Darwin OR iOS` (`:22-26`)
- Dependency includes are dispatched per `CMAKE_SYSTEM_NAME`: `windows-vcpkg.cmake` (Windows only, `:45-47`), then unconditional `cmake/dependencies/common.cmake` (`:49`), then platform-specific `android.cmake`/`mac.cmake`/`ios.cmake`/`linux.cmake`/`openbsd.cmake`/`windows.cmake` (`:51-73`)
- `include(cmake/ios-toolchain-populate.cmake)` only for iOS (`:76-78`) — **this is the CMake-to-Xcode entry point** (see B.4)

**`cmake/ios-toolchain-populate.cmake`** (full read, 15 lines): sets `PLATFORM=OS64COMBINED`, then `FetchContent`-pulls the third-party [`leetal/ios-cmake`](https://github.com/leetal/ios-cmake) toolchain file (pinned commit `06465b27698424cf4a04a5ca4904d50a3c966c45`) and `include()`s it. This is how `-GXcode -DCMAKE_SYSTEM_NAME=iOS` gets turned into a real multi-arch/simulator-aware Xcode project — already wired for LUS itself.

**`cmake/dependencies/ios.cmake`** (full read, 91 lines) — FetchContent-based, all with `OVERRIDE_FIND_PACKAGE` so a system copy is preferred if present:
| Dependency | Version/tag | Mechanism |
|---|---|---|
| SDL2 | `release-2.32.10` | FetchContent from `libsdl-org/SDL` |
| nlohmann-json | `v3.12.0` | FetchContent |
| tinyxml2 | `11.0.0` | FetchContent |
| spdlog | `v1.16.0` | FetchContent |
| libzip | `v1.11.4` | FetchContent, static, tools/tests/examples/docs/fuzzing all off |
| metal-cpp | tag `macOS13_iOS16` of `briaguya-ai/single-header-metal-cpp` | FetchContent, header-only |
| ImGui (from `common.cmake`) | `v1.91.9b-docking` | + `imgui_impl_metal.mm` added to the `ImGui` target specifically in `ios.cmake:82-88` |

**`cmake/dependencies/common.cmake`** (full read, 310 lines) — platform-agnostic deps pulled for every target including iOS:
| Dependency | Version/tag | Mechanism | Notes |
|---|---|---|---|
| ImGui | `v1.91.9b-docking` (ocornut/imgui) | FetchContent + local patch `patches/imgui-fixes-and-config.patch` | base sources always include `imgui_impl_opengl3.cpp`+`imgui_impl_sdl2.cpp` (`:30-34`) even on iOS where OpenGL is dead code — harmless but wasted compile |
| StormLib | `v9.25` | FetchContent, only if `INCLUDE_MPQ_SUPPORT` (SoH sets this **ON** unconditionally, `soh/CMakeLists.txt:186`) | **no iOS-specific exclusion — will be compiled for iOS** since the option is platform-agnostic |
| stb (stb_image.h) | pinned commit `0bc88af4...` | raw `file(DOWNLOAD)`, not git | fine for iOS |
| libgfxd | commit `008f73d...` | FetchContent, only if `GFX_DEBUG_DISASSEMBLER` (SoH sets `GFX_DEBUG_DISASSEMBLER ON`, `soh/CMakeLists.txt:179`) | pure C11, should build |
| thread-pool (`bshoshany/thread-pool`) | `v4.1.0` | FetchContent | |
| prism (`KiritoDv/prism-processor`) | commit `1de0544...` | FetchContent | has an MSVC/sccache-specific workaround (`:115-132`), nothing iOS-specific |
| monocypher | commit `0d85f98...` | FetchContent | |
| libtcc (TinyCC, `ENABLE_SCRIPTING` only) | branch `mob` | FetchContent | **has real, already-written iOS cross-compile handling**: disables `CONFIG_CODESIGN` for iOS (`:186-189`), builds a host-native `c2str` tool when cross-compiling and strips `SDKROOT`/`IPHONEOS_DEPLOYMENT_TARGET` env vars for it (`:192-218`), disables code signing on the TCC targets for Apple (`:298-307`). SoH does **not** enable `ENABLE_SCRIPTING` today (not referenced in `soh/CMakeLists.txt`), so this iOS path is unused but present. |

**Backend toggle options** (`src/CMakeLists.txt:13-14`): `USE_OPENGLES` (OFF default), `GFX_DEBUG_DISASSEMBLER` (OFF default). Actual backend compile-definitions logic is the `if (CMAKE_SYSTEM_NAME STREQUAL "iOS") ... else() ... ENABLE_OPENGL ... endif()` block at `src/CMakeLists.txt:176-213` — **iOS never gets `ENABLE_OPENGL` defined**, so `gfx_opengl.cpp` (guarded `#ifdef ENABLE_OPENGL`, `src/fast/backends/gfx_opengl.cpp:2`) compiles to an empty translation unit on iOS and only Metal is live. Note: `src/fast/CMakeLists.txt:38-40` also tries to `list(FILTER ... EXCLUDE REGEX "graphic/Fast3D/backends/gfx_opengl*")` for iOS at the *source-file-list* level, but the regex path (`graphic/Fast3D/backends/...`) doesn't match the actual glob output (`backends/gfx_opengl.cpp`, since the glob already runs relative to `src/fast/`) — this filter is **dead code** (leftover from the pre-refactor directory layout, same one still live in `lus-wiiu`). It's harmless only because the `#ifdef ENABLE_OPENGL` internal guard does the real job.

**Xcode bundle-ID / signing** (`src/CMakeLists.txt:176-213`, confirmed already in place):
```
set_xcode_property(${PROJECT_NAME} PRODUCT_BUNDLE_IDENTIFIER ${BUNDLE_ID} All)
if(NOT SIGN_LIBRARY):
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY = "" / XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED = "NO"
    (applied to libultraship itself, and — if targets exist — SDL2 and zip)
```
Plus `find_Library`/`find_library` for `Foundation`, `AVFoundation`, `Metal`, `QuartzCore`, `CoreAudio`, `AudioToolbox` for `Darwin OR iOS` (`:113-121`), and `Cocoa`+`Threads` for `Darwin` only (`:104-111`, correctly excluded on iOS since Cocoa/AppKit don't exist there).

**Which SDL2 version is pinned?** `release-2.32.10`, consistently used for both iOS (`cmake/dependencies/ios.cmake:9`) and Android (`cmake/dependencies/android.cmake:8`). Windows uses whatever `vcpkg`'s `sdl2` port resolves to (`cmake/dependencies/windows-vcpkg.cmake:16`, unpinned at the LUS level — floats with the vcpkg baseline). macOS/Linux (`cmake/dependencies/mac.cmake:35`, `cmake/dependencies/linux.cmake:2`) use `find_package(SDL2 REQUIRED)` against whatever's installed on the system (Homebrew/apt), also unpinned.

## B.2 SoH CMake — consuming LUS, platform wiring, packaging

**Top-level `soh/CMakeLists.txt`** (322 lines, full read): `add_subdirectory(libultraship ...)` at `:196`; sets `INCLUDE_MPQ_SUPPORT ON` (`:186`) and `GFX_DEBUG_DISASSEMBLER ON` (`:179` — wait, actually set via `soh/CMakeLists.txt:179` `set(GFX_DEBUG_DISASSEMBLER ON)`) globally before pulling LUS in, so both StormLib and libgfxd get compiled into every SoH platform target including any future iOS one. Platform conditionals present: `Windows` (`:83-124`, vcpkg bootstrap+triplet), `NintendoSwitch` (`:129`), `Linux` (`:157,207,263,313`), `Darwin` (`:273-307`, OSX iconset generation via `sips`/`iconutil`, `fixup_bundle`, macOS `.app` rename), `Windows|NintendoSwitch|CafeOS` grouped for README packaging (`:309`), and CPack generator selection (`:313-319`: `External` for Linux, `ZIP` for Windows/Switch/WiiU, `Bundle` for Darwin). **`CMAKE_SYSTEM_NAME STREQUAL "iOS"` does not appear anywhere in this file** — no compile flags, no packaging step, no CPack generator (would fall through to nothing/default), no bundle-icon generation. `CMAKE_OSX_DEPLOYMENT_TARGET "10.15"` (`:7`) is a macOS-only setting; iOS needs its own `IPHONEOS_DEPLOYMENT_TARGET`/`CMAKE_OSX_DEPLOYMENT_TARGET` value passed independently (LUS's own iOS CI does `-DCMAKE_OSX_DEPLOYMENT_TARGET=14.0`, `lus-pinned/.github/workflows/build-validation.yml:54`).

**`soh/soh/CMakeLists.txt`** (776 lines, extensively read): `enable_language(OBJCXX)` only for `Darwin` (`:9-13`) — **not iOS**, unlike LUS's own top-level which correctly does `Darwin OR iOS` (`lus-pinned/CMakeLists.txt:22`). Not currently a problem (SoH has no `.mm` files that would need to compile on iOS — see below), but inconsistent with the LUS-level precedent and would bite the moment SoH gains an iOS-only Objective-C++ file (e.g. a real app-lifecycle shim).

`add_executable(${PROJECT_NAME} ${ALL_FILES})` (`:231`) — plain executable target, **no `MACOSX_BUNDLE` / iOS bundle target properties set anywhere**; the macOS `.app` shape is entirely produced after the fact via CPack's `Bundle` generator + `install(CODE ...)` (`fixup_bundle`, `:300-305`) + the standalone `CreateOSXIcons` custom target (`:274-291`), not via `set_target_properties(... MACOSX_BUNDLE TRUE ...)`. Getting a real iOS `.app`/`.ipa` this way would need an analogous, currently-nonexistent path (Xcode-generator projects normally want `MACOSX_BUNDLE TRUE` plus `XCODE_ATTRIBUTE_*` properties directly on the target, not a post-hoc CPack bundle step, which is a macOS/CPack-only concept).

Per-platform dependency wiring (`soh/CMakeLists.txt` — actually `soh/soh/CMakeLists.txt:333-408` compile defs, `:484-593` compile options, `:673-716` link deps) is a 4-way `if/elif/elif/else` over `Windows` / `CafeOS` / `NintendoSwitch` / **everything else** (`:694-716`, `:560-592`, `:391-407`). Since there is no `iOS` branch, **an iOS configure would fall into the generic "everything else" bucket**, which does:
```cmake
find_package(SDL2)
find_package(Threads REQUIRED)
find_package(Ogg REQUIRED)
find_package(Vorbis REQUIRED)
find_package(Opus REQUIRED)
find_package(OpusFile REQUIRED)
```
(`:695-701`) and links `SDL2_net::SDL2_net` (`:712`) plus `ZAPDLib` (`:704`, `:172-184`/`:622-626` gate `ZAPDLib`/`Extractor` off only for `NintendoSwitch|CafeOS`, so it stays on for the hypothetical iOS branch too) — **none of Ogg/Vorbis/Opus/OpusFile/SDL2_net/ZAPDLib have any FetchContent/vendoring fallback anywhere in SoH's CMake** (grep for `FetchContent` in `soh/soh/CMakeLists.txt` only turns up `dr_libs`, `:293-300`). On desktop these are satisfied by vcpkg (Windows) or system packages (Linux/macOS via Homebrew/apt); **no such provider exists for iOS**, so this is a hard CMake-configure-time failure for a hypothetical iOS build today (see B.3/B.4 gap list).

`INSTALL(TARGETS soh DESTINATION . COMPONENT ship)` guarded `NOT Darwin|NintendoSwitch|CafeOS` (`:718-720`) — iOS would hit the *generic* `INSTALL` path (wrong; needs the platform's own bundle install like Switch/WiiU get, `:739-776`) unless explicitly excepted. `soh/macosx/Info.plist.in` (`:731`, full text read) is configured only for Darwin and is macOS-specific (`LSMinimumSystemVersion 10.15`, `LSEnvironment` pointing at `~/Library/Application Support/...`, no `UILaunchScreen`/`UIRequiredDeviceCapabilities`/`UISupportedInterfaceOrientations`) — **no iOS Info.plist template exists**.

`grep -rn "SIGN_LIBRARY\|BUNDLE_ID\|DEVELOPMENT_TEAM\|PRODUCT_BUNDLE_IDENTIFIER" soh/` → **zero hits**. LUS exposes the `SIGN_LIBRARY`/`BUNDLE_ID` options (`lus-pinned/CMakeLists.txt:14-16`) but SoH never sets them when it pulls LUS in, so a real iOS build would silently get `BUNDLE_ID=com.example.libultraship` unless someone wires this through.

`soh/docs/BUILDING.md` documents Switch (`:286-303`) and Wii U (`:320-324`) build commands in detail. **No iOS or Android section exists** in that doc at all.

## B.3 Third-party dependency iOS/arm64 buildability

| Dependency | iOS arm64 status | Basis |
|---|---|---|
| SDL2 `2.32.10` | **known-yes** | SDL2 has first-class iOS support upstream (own `src/video/uikit` backend); LUS already builds it via FetchContent in `ios.cmake` |
| ImGui `1.91.9b-docking` + `imgui_impl_metal.mm`/`imgui_impl_sdl2.cpp` | **known-yes** | Dear ImGui ships an official Metal backend; already wired for iOS in `ios.cmake:82-88` |
| metal-cpp (`briaguya-ai/single-header-metal-cpp`, tag `macOS13_iOS16`) | **known-yes** | tag name literally advertises iOS 16 support; header-only |
| spdlog `v1.16.0` | **known-yes** | pure C++17/20 header+source lib, no platform deps; the Wii U fork's `spdlog-wiiu.patch` (removing `thread_local`) is not needed on iOS since Apple Clang fully supports TLS |
| nlohmann-json `v3.12.0` | **known-yes** | header-only, portable |
| tinyxml2 `11.0.0` | **known-yes** | small portable C++ lib |
| libzip `v1.11.4` | **known-yes with caveats** | portable C, but pulls zlib/bzip2 transitively (not explicitly vendored in `ios.cmake` — relies on find_package or its own bundled minizip fallback; needs verification that libzip's own CMake correctly cross-compiles its optional zlib/bzip2/openssl detection under the iOS toolchain) |
| StormLib `v9.25` | **unknown** | portable C++, no official iOS statement found; compiled unconditionally for iOS today because `INCLUDE_MPQ_SUPPORT` is platform-agnostic in both LUS and SoH — worth a real build test |
| thread-pool (`bshoshany/thread-pool` v4.1.0) | **known-yes** | header-only, standard C++17 threads; only needed the Wii U TLS patch because of devkitPPC, not applicable to iOS |
| prism-processor | **unknown** | small custom lib, no platform-specific code observed, likely fine but untested on iOS |
| monocypher | **known-yes** | pure portable C |
| libtcc (TinyCC, only if `ENABLE_SCRIPTING`, currently off in SoH) | **known-yes, with real work already done** | `common.cmake:186-307` has explicit iOS cross-compile handling (host `c2str` tool, code-signing disabled, `CONFIG_CODESIGN` undef) |
| dr_libs (SoH-only, `soh/soh/CMakeLists.txt:293-300`) | **known-yes** | header-only single-file C audio decoders, fully portable |
| stb_image.h | **known-yes** | header-only, portable |
| libgfxd (if `GFX_DEBUG_DISASSEMBLER`, ON by default in SoH) | **known-yes** | pure C11, no platform deps observed |
| GLEW | **not needed for iOS** | only pulled by `mac.cmake` (macOS OpenGL/GLEW path, `:38-39`); `ios.cmake` never references it since OpenGL is dead on iOS |
| Ogg / Vorbis / Opus / OpusFile (SoH-level, `soh/soh/CMakeLists.txt:698-701`) | **known-yes upstream, but no acquisition path for iOS today** | these are portable C libraries with iOS support elsewhere in the ecosystem (e.g. via cocoapods/prebuilt xcframeworks), but SoH's CMake only does `find_package(... REQUIRED)` with zero FetchContent fallback — **this is a concrete build-system gap**, not a portability problem with the libraries themselves |
| SDL2_net (SoH-level) | **known-yes upstream**, same gap as above — `find_package` only, no iOS acquisition path |
| ZAPDLib / ZAPD (asset extractor, linked into `soh` by default outside Switch/WiiU) | **untested/unknown for iOS**, and arguably shouldn't even be linked into a mobile app (see B.4 gap list — no exclusion branch for iOS exists) |

## B.4 CMake-to-Xcode: what's missing for `cmake -G Xcode -DCMAKE_SYSTEM_NAME=iOS` on SoH

**LUS itself is iOS-Xcode-ready**: `lus-pinned/README.md:53-59` documents `cmake -H. -Bbuild -GXcode -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0`, and CI proves it (`lus-pinned/.github/workflows/build-validation.yml:54`: `cmake --no-warn-unused-cli -H. -Bbuild-cmake -GXcode -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 -DCMAKE_BUILD_TYPE:STRING=Release`) — this validates that **the LUS library alone** configures and (presumably) builds as an Xcode/iOS static library in CI today. `cmake/ios-toolchain-populate.cmake` supplies the `leetal/ios-cmake` toolchain automatically, so no external `-DCMAKE_TOOLCHAIN_FILE=` is required by the caller.

**SoH would break immediately** if you pointed the same flags at `soh/CMakeLists.txt`, for concrete, evidenced reasons:
1. `soh/soh/CMakeLists.txt:695-716` (the generic "else" dependency branch) does `find_package(Ogg/Vorbis/Opus/OpusFile REQUIRED)` and `find_package(SDL2_net)` with **no FetchContent fallback** — these packages are not installed in an iOS cross-compile sysroot, so `cmake` configure fails at this point (fatal `find_package ... REQUIRED` error) unless someone pre-supplies iOS builds of all four out-of-band.
2. `soh/soh/CMakeLists.txt:9-13` only does `enable_language(OBJCXX)` for `Darwin`, not iOS — would need fixing the moment SoH gets its own `.mm` file (not yet, so not fatal today, but inconsistent with LUS's own `Darwin OR iOS` pattern at `lus-pinned/CMakeLists.txt:22`).
3. `soh/CMakeLists.txt` (top-level) has **zero** `iOS` branch anywhere — no compile definitions, no packaging/CPack generator, no `Info.plist`, no icon generation, no `SIGN_LIBRARY`/`BUNDLE_ID` passthrough to the LUS `add_subdirectory` call. Configure would likely still *succeed* at the top level (nothing there is `REQUIRED`-gated on iOS specifically) but produce a target with no code signing identity, the default `com.example.libultraship` bundle id on the LUS side, and a plain executable (not an app bundle) on the SoH side.
4. `ZAPDLib`/`ZAPD` (the asset extractor+its CMake target) gets linked into the `soh` executable by default outside `NintendoSwitch|CafeOS` (`soh/soh/CMakeLists.txt:172-184`, `:622-626`, `:704`) — nothing excludes it for iOS, and it's unclear ZAPD (a native-tool-chain-dependent asset compiler meant to run on the *build host*, not the *target device*) is even meant to be linked into the shipping app; the Switch/WiiU precedent (excluding it) strongly suggests iOS should do the same, but no one has added that branch.
5. CoreAudioAudioPlayer link failure (see below) would break the **LUS** side of the build specifically when SoH links against it for iOS, since SoH doesn't set anything that would fix it.

**Root-cause bugs found in LUS itself that would break an iOS build even in isolation** (i.e., not SoH's fault):
- **`CoreAudioAudioPlayer` link failure on iOS.** `lus-pinned/src/ship/audio/Audio.cpp:3-5,24-28,51-53` compiles a `case AudioBackend::COREAUDIO: mAudioPlayer = std::make_shared<CoreAudioAudioPlayer>(...)` branch and pushes `COREAUDIO` into `mAvailableAudioBackends` whenever `__APPLE__` is defined — true for iOS. But `lus-pinned/src/ship/CMakeLists.txt:16-18` only compiles `CoreAudioAudioPlayer.cpp` into the target when `CMAKE_SYSTEM_NAME STREQUAL "Darwin"` — **iOS is excluded**, since the condition is `NOT CMAKE_SYSTEM_NAME STREQUAL "Darwin"`. Since `Audio.cpp` references the class's constructor/destructor/methods unconditionally in a compiled (non-`#ifdef`-stripped) code path, this is a straightforward **undefined-symbol link error** on iOS as currently configured, contradicting LUS's own doc comment at `lus-pinned/include/ship/audio/CoreAudioAudioPlayer.h:19` ("This backend is only available on Apple platforms (macOS / iOS)") and `docs/PORTING.md`'s explicit statement that CoreAudio is "macOS / iOS." Compare with the *correctly*-guarded `macUtils.mm` a few lines above/below in the same file (`:66-68`, Darwin-only, intentionally — it uses AppKit/Cocoa, unavailable on iOS) — the CoreAudio exclusion looks like a copy-paste of that pattern applied somewhere it shouldn't have been. **One-line CMake fix**: change `NOT CMAKE_SYSTEM_NAME STREQUAL "Darwin"` to `NOT (CMAKE_SYSTEM_NAME STREQUAL "Darwin" OR CMAKE_SYSTEM_NAME STREQUAL "iOS")` at `ship/CMakeLists.txt:16`, matching the pattern already used correctly for `AppleFolderManager.mm` two lines earlier (`:62-64`).
- **`docs/PORTING.md`'s platform table overstates iOS support**: it lists iOS rendering backends as "OpenGL, Metal" (`lus-pinned/docs/PORTING.md`, Supported Platforms table), but `src/CMakeLists.txt:176-213` never defines `ENABLE_OPENGL` for iOS — only Metal is actually reachable. Minor doc inaccuracy, but worth flagging since it could mislead a porter into assuming OpenGL ES is a fallback path on iOS.

### Summary: what's MISSING for a real iOS build of SoH (gap list)

**Build-system (blocking, in rough priority order):**
1. No iOS branch anywhere in `soh/CMakeLists.txt` or `soh/soh/CMakeLists.txt` — compile defs, compile options, dependency acquisition, install/packaging all need a new `elseif(CMAKE_SYSTEM_NAME STREQUAL "iOS")` arm mirroring the existing Switch/WiiU/Darwin pattern.
2. No FetchContent/vendoring for Ogg, Vorbis, Opus, OpusFile, SDL2_net at the SoH level — `find_package(... REQUIRED)` will fail to configure for iOS with no system package manager providing these.
3. `CoreAudioAudioPlayer.cpp` isn't compiled for iOS in LUS (`ship/CMakeLists.txt:16-18`) despite `Audio.cpp` requiring it whenever `__APPLE__` is defined — guaranteed link error, one-line CMake fix identified above.
4. No iOS `Info.plist` template, no app-icon/launch-screen asset pipeline, no `MACOSX_BUNDLE`/Xcode bundle target properties on the `soh` executable target, no `SIGN_LIBRARY`/`BUNDLE_ID`/`DEVELOPMENT_TEAM` wiring from SoH into LUS's existing (but SoH-unused) signing options.
5. `ZAPDLib`/asset-extractor gets linked into the shipping binary by default; needs an iOS exclusion analogous to the existing Switch/WiiU one.
6. No CPack/packaging story for iOS (`soh/CMakeLists.txt:313-319` has no iOS branch — would need a `.ipa`/archive step, or to skip CPack for iOS entirely in favor of Xcode's own archive/export flow).
7. `soh/soh/CMakeLists.txt` only `enable_language(OBJCXX)` for Darwin, not iOS (latent, not yet fatal).
8. StormLib's iOS-arm64 buildability is unverified (built by default since `INCLUDE_MPQ_SUPPORT ON` is unconditional in SoH).

**Platform-abstraction (needed for a working app, not just a build):**
1. No on-screen/virtual touch controller anywhere in LUS's controller layer — the entire input stack is keyboard/mouse/SDL-physical-gamepad; a phone with no external MFi controller has no way to play.
2. No SDL app-lifecycle event handling (background/foreground/low-memory/terminating) — needed to avoid iOS watchdog kills and to pause the always-running game thread correctly.
3. No Retina/HiDPI ImGui scaling for iOS (Android-only today, `Gui.cpp:73-77`, `GameOverlay.cpp:240`).
4. `main.c`'s entry point is gated `#ifdef _WIN32 SDL_main #else int main #endif` — needs verification (or an explicit fix) that this resolves to `SDL_main` on iOS the way SDL2 expects.
5. `MobileImpl.cpp`'s entire feature set is soft-keyboard show/hide; no safe-area, orientation, haptics, or App Store entitlement/permissions handling exists at either the LUS or SoH layer.
6. Zero `__IOS__`-aware branches in SoH's own console-parity logic (SaveManager file-rename behavior, ResolutionEditor aspect-lock option, FileSelectEnhancements drag-drop text, OTRGlobals fatal-error UX, etc.) — SoH would need to decide, file by file, whether iOS behaves like a console (fixed screen, no drag/drop, sandboxed FS) or like desktop, and add the corresponding `__IOS__` arms; currently only one file (`SohStatsWindow.cpp`) has any iOS awareness at all.
