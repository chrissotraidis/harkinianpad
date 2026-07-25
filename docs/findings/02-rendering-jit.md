# LUS/SoH iOS Feasibility — Rendering Path + Runtime Codegen Hard-Check

Paths referenced (scratchpad clones):
- `lus-pinned` = libultraship at SoH's pinned commit 2bfbde3 (what SoH actually builds)
- `lus` = libultraship main (latest)
- `soh` = Ship of Harkinian main
- All line numbers are from the files as read in this session.

---

## (A) Metal backend

### A.0 Headline finding: this LUS fork already ships iOS build plumbing

Before getting into API specifics: this is **not** a stock upstream libultraship checkout. Both `lus-pinned` and `lus` (main) already contain a full iOS CMake toolchain path, present **identically** in both trees:

- `CMakeLists.txt:14-18` — `if(CMAKE_SYSTEM_NAME STREQUAL "iOS")` sets `SIGN_LIBRARY`, `BUNDLE_ID`, `CMP0077` policy.
- `CMakeLists.txt:22-26` — `Darwin OR iOS` → `enable_language(OBJCXX)`, forces `-fobjc-arc`.
- `CMakeLists.txt:59-61` — `include(cmake/dependencies/ios.cmake)` for iOS.
- `CMakeLists.txt:76-78` — `include(cmake/ios-toolchain-populate.cmake)` for iOS.
- `cmake/dependencies/ios.cmake` (13 lines) — fetches `metal-cpp` (tag `macOS13_iOS16`, i.e. explicitly built for both macOS 13 and iOS 16), adds `imgui_impl_metal.mm` to ImGui, links `SDL2::SDL2-static`.
- `src/fast/CMakeLists.txt:26-32` — excludes DirectX/DXGI backends unless Windows; excludes Metal backend unless `Darwin`/`iOS`; **explicitly excludes `gfx_opengl*` when `CMAKE_SYSTEM_NAME STREQUAL "iOS"`** — i.e. on iOS only the Metal backend is compiled in, OpenGL/GLES is not built at all.
- `src/CMakeLists.txt:113-121` — Darwin/iOS both link `Foundation`, `AVFoundation`, `Metal`, `QuartzCore`, `CoreAudio`, `AudioToolbox`.
- `src/CMakeLists.txt:176-190` — iOS-specific target: defines `__IOS__`, sets `PRODUCT_BUNDLE_IDENTIFIER`, disables code signing when `SIGN_LIBRARY` is off (dev-build convenience).
- `src/ship/CMakeLists.txt:97-101` — `Android OR iOS` → compiles `port/mobile/MobileImpl.cpp` (mobile-specific ImGui glue, see A.4).
- `src/ship/CMakeLists.txt:62-64` — `Darwin OR iOS` compiles `utils/AppleFolderManager.mm`.

Since `soh/CMakeLists.txt:196` (`add_subdirectory(libultraship ...)`) pulls this LUS tree directly and `soh/soh/CMakeLists.txt` sets no scripting/iOS-blocking options, SoH inherits this iOS path as-is. This significantly changes the framing of the investigation: the question is not "can Metal be made to work on iOS" but "how far does this already-iOS-aware backend get, and what's still missing."

### A.1 macOS-only vs Apple-generic constructs in gfx_metal.cpp / gfx_metal_shader.cpp

Read in full: `lus-pinned/src/fast/backends/gfx_metal.cpp` (1298 lines), `lus-pinned/include/fast/backends/gfx_metal.h` (246 lines), `lus-pinned/src/fast/backends/gfx_metal_shader.cpp` (286 lines). `lus` main is essentially line-for-line identical (diffs are only ±2 lines from unrelated context, confirmed by grep line-number alignment on all landmark symbols below).

**Storage modes — clean.** Grepped `StorageModeManaged|ResourceStorageModeManaged|CPUCacheMode` across all of `src/` and `include/` in both trees:
- `gfx_metal.cpp:87` — vertex buffer pool: `MTL::ResourceStorageModeShared` (portable).
- `gfx_metal.cpp:357` — texture: `MTL::StorageModeShared` (portable).
- `gfx_metal.cpp:566,569` — frame/coord uniform buffers: `MTL::ResourceCPUCacheModeDefaultCache` (this is a *CPU cache mode* option bit, not the macOS-only `StorageModeManaged`; it's valid on iOS).
- `gfx_metal.cpp:610` — screen readback buffer: `MTL::ResourceStorageModeShared`.
- `gfx_metal.cpp:724,793,837` — depth/color/MSAA render targets: `MTL::StorageModePrivate` (portable, GPU-only).
- `gfx_metal.cpp:1032` — depth query output buffer: `MTL::ResourceOptionCPUCacheModeDefault`.

**Zero occurrences of `MTLResourceStorageModeManaged` / `MTL::StorageModeManaged` anywhere in this backend.** That storage mode (macOS-only, unavailable on iOS) is simply not used — the backend was written storage-mode-portable from the start. This is the single most important "it already works" finding for Metal.

**Existing `__IOS__` branches (2 total in gfx_metal.cpp):**
- `gfx_metal.cpp:65-73` (`NonUniformThreadGroupSupported`) —
  ```cpp
  #ifdef __IOS__
      // iOS devices with A11 or later support dispatch threads
      return mDevice->supportsFamily(MTL::GPUFamilyApple4);
  #else
      // macOS devices with Metal 2 support dispatch threads
      return mDevice->supportsFamily(MTL::GPUFamilyMac2);
  #endif
  ```
  Gates whether `dispatchThreads` (non-uniform threadgroups) vs `dispatchThreadgroups` is used at two call sites (`gfx_metal.cpp:1071-1075` depth query, `1235-1238` RGB5A1 readback compute).
- `gfx_metal.cpp:1284-1296` (`Metal_IsSupported`) —
  ```cpp
  #ifdef __IOS__
      // iOS always supports Metal and MTLCopyAllDevices is not available
      return true;
  #else
      NS::Array* devices = MTLCopyAllDevices();
      ...
  #endif
  ```
  `MTLCopyAllDevices()` is a macOS-only enumeration API; correctly avoided on iOS.

**GPU family checks (Apple-generic, correct for iOS):**
- `gfx_metal.cpp:136` `GetMaxTextureSize()`: `mDevice->supportsFamily(MTL::GPUFamilyApple3) ? 16384 : 8192` — uses the Apple-family enum, which is the cross-Apple-platform-correct API (works for iOS/tvOS/macOS-Apple-Silicon uniformly). No `GPUFamilyMac*` leakage here.

**CAMetalLayer acquisition — via SDL, not raw NSWindow/UIWindow:**
- `gfx_metal.cpp:79` `mLayer = (CA::MetalLayer*)SDL_RenderGetMetalLayer(renderer)` — the layer comes from an `SDL_Renderer` created with `SDL_CreateRenderer(..., SDL_RENDERER_ACCELERATED)` after `SDL_SetHint(SDL_HINT_RENDER_DRIVER, "metal")` (`gfx_sdl2.cpp:345,426`). This is SDL2's own Metal renderer abstraction, which already handles the macOS `NSView`/`CAMetalLayer` vs iOS `UIView`/`CAMetalLayer` split internally — the LUS code itself never touches `NSWindow`/`NSView`/`UIView` directly for this. No `AppKit`/`UIKit` dependency in `gfx_metal.cpp`/`gfx_metal.h`/`gfx_metal_shader.cpp`.

**No `NSWindow`/`NSView`/`AppKit`/`UIKit` in the Metal or shader files.** `AppKit`/`NSWindow`/`NSView` references anywhere in the tree are confined to two files, neither of which is the Metal renderer:
- `lus-pinned/src/ship/utils/AppleFolderManager.mm` (file-picker dialogs; compiled for `Darwin OR iOS`, `src/CMakeLists.txt:58-60`/`src/ship/CMakeLists.txt:62-64`).
- `lus-pinned/src/ship/utils/macUtils.mm` (native fullscreen toggle; compiled for `Darwin` **only** — see A.1a gap below).

**MSAA setup — portable.** `gfx_metal.cpp:144-151` probes `mDevice->supportsTextureSampleCount(n)` for `n` in `1..METAL_MAX_MULTISAMPLE_SAMPLE_COUNT` (8, `gfx_metal.h:17`) — a standard `MTLDevice` query available on iOS. MSAA resolve paths (`gfx_metal.cpp:790-799, 848-856, ResolveMSAAColorBuffer:970-1021`) use `StoreActionStoreAndMultisampleResolve` / blit encoders — all portable Metal API, no macOS gate.

**Pixel formats — portable.** `BGRA8Unorm` / `BGRA8Unorm_sRGB` (color), `Depth32Float` (depth) throughout — all valid on iOS. No `Depth24Unorm_Stencil8` (which *is* macOS-only in Metal) is used.

**A.1a — Concrete gap found: native-fullscreen toggle is `__APPLE__`-gated, not `__APPLE__ && !__IOS__`-gated, but its implementation is Darwin-only.**
This is a real inconsistency in the current tree, present identically in `lus-pinned` and `lus` main:
- `include/ship/utils/macUtils.h` declares `toggleNativeMacOSFullscreen(SDL_Window*)` and `isNativeMacOSFullscreenActive(SDL_Window*)` unconditionally (only guarded by `#ifdef __cplusplus` for `extern "C"`, not by any platform macro).
- `gfx_sdl2.cpp:29-32` includes `"ship/utils/macUtils.h"` under `#elif __APPLE__` (which is true for iOS too, since iOS defines `__APPLE__`).
- `gfx_sdl2.cpp:238-243` (`SetFullscreenImpl`) calls `isNativeMacOSFullscreenActive`/`toggleNativeMacOSFullscreen` under `#if defined(__APPLE__)`.
- `gfx_sdl2.cpp:677-685` (`HandleEvents`, fullscreen resync) calls `isNativeMacOSFullscreenActive` under `#ifdef __APPLE__`.
- But the *implementation* `macUtils.mm` (which does `[nswindow toggleFullScreen:nil]` and reads `NSWindowStyleMaskFullScreen` via `Cocoa.h`) is only added to the build for `CMAKE_SYSTEM_NAME STREQUAL "Darwin"` — `src/ship/CMakeLists.txt:66-68` — **not** `iOS`. `NSWindow`/`Cocoa.h` don't exist on iOS at all.
- Net effect: as this code stands today, an iOS build of `gfx_sdl2.cpp` would reference `toggleNativeMacOSFullscreen`/`isNativeMacOSFullscreenActive` with no compiled definition anywhere in the iOS target → **link error**. This must be fixed (e.g. `#if defined(__APPLE__) && !defined(__IOS__)` at both call sites, or teach `macUtils.mm` to no-op under `TARGET_OS_IPHONE`) before an iOS build of this LUS tree will actually link. It's a small, mechanical fix, not an architectural blocker — but it demonstrates the iOS path in this fork is scaffolded, not fully exercised/CI-tested (there is no iOS CI job or Xcode iOS scheme found in `soh/` — see A.5).
- Confirmed present verbatim in `lus` main too: `gfx_sdl2.cpp:236-239` and `:672-673`, same gating, same gap.

### A.2 Fast3D rendering interface — GfxRenderingAPI / GfxWindowManagerAPI members

`gfx_metal.h:129-239` — `class GfxRenderingAPIMetal final : public GfxRenderingAPI`. Full override surface (all implemented, `gfx_metal.h:132-175`): `GetName`, `GetMaxTextureSize`, `GetClipParameters`, `UnloadShader`, `LoadShader`, `CreateAndLoadNewShader`, `LookupShader`, `ShaderGetInfo`, `ClearShaderCache`, `NewTexture`, `SelectTexture`, `UploadTexture`, `SetSamplerParameters`, `SetDepthTestAndMask`, `SetCurrentPrimDepth`, `SetZmodeDecal`, `SetViewport`, `SetScissor`, `SetUseAlpha`, `DrawTriangles`, `Init`, `OnResize`, `StartFrame`, `EndFrame`, `FinishRender`, `CreateFramebuffer`, `UpdateFramebufferParameters`, `StartDrawToFramebuffer`, `CopyFramebuffer`, `ClearFramebuffer`, `ReadFramebufferToCPU`, `ResolveMSAAColorBuffer`, `GetPixelDepth`, `GetFramebufferTextureId`, `SelectTextureFb`, `DeleteTexture`, `SetTextureFilter`, `GetTextureFilter`, `SetSrgbMode`, `GetTextureById`. All immediate-mode style, GPU-portable — nothing here assumes a desktop windowing model.

Window-manager side (`GfxWindowBackendSDL2`, `gfx_sdl2.cpp`) is where desktop assumptions live:
- `SetFullscreenImpl` (`gfx_sdl2.cpp:217-274`) — has the native-macOS-fullscreen path (A.1a) plus a generic SDL `SDL_WINDOW_FULLSCREEN`/`SDL_WINDOW_FULLSCREEN_DESKTOP` path (`:245-249`) for non-Apple. iOS doesn't really have a "fullscreen toggle" concept (app *is* fullscreen); `Fast3dWindow::Init` (`lus-pinned/src/fast/Fast3dWindow.cpp:60-97`) already special-cases this: `gameMode = true` for `__ANDROID__ || __IOS__` (`Fast3dWindow.cpp:77-78`), which forces `isFullscreen` on unconditionally and defaults resolution to 1280×800 (`:91-93`). So the "vsync toggle / fullscreen switching" desktop assumption is substantially already handled for mobile, modulo the A.1a link gap.
- `CanDisableVsync()` (`gfx_sdl2.cpp:776-778`) unconditionally returns `true` and vsync is toggled via `SDL_GL_SetSwapInterval`/`SDL_RenderSetVSync` (`gfx_sdl2.cpp:745-746`) — both are SDL-portable calls; no explicit iOS override, should be fine since SDL owns the platform dispatch.
- `SetMaxFrameLatency` (`gfx_sdl2.cpp:768-770`) is a no-op ("Not supported by SDL") on all platforms — not iOS-specific.
- Window creation flags (`gfx_sdl2.cpp:376-386`): `__IOS__` gets `SDL_WINDOW_BORDERLESS | SDL_WINDOW_SHOWN` (no `SDL_WINDOW_RESIZABLE`/`SDL_WINDOW_ALLOW_HIGHDPI`, which non-iOS gets) plus `SDL_WINDOW_METAL` when not using OpenGL. Sensible for a fixed-orientation mobile app.
- `GetDimensions` (`gfx_sdl2.cpp:527-534`) and the `SDL_WINDOWEVENT_SIZE_CHANGED` handler (`gfx_sdl2.cpp:641-647`) both branch on `#ifdef __APPLE__` to use `SDL_GetWindowSize` (points, not pixels) rather than `SDL_GL_GetDrawableSize` — again `__APPLE__`-wide (macOS + iOS together), not iOS-exclusive, so no special gap here, this one's actually correct for both.

### A.3 Shader pipeline — runtime GPU-shader compilation, not CPU codegen

Confirmed: MSL shader source is generated **at runtime** from `CCFeatures` (color-combiner state) and handed to `MTLDevice::newLibrary`, which is Apple's own JIT-compiles-GPU-bytecode-on-device API — this is a completely normal, App-Store-legal, standard Metal usage pattern (every Metal app that builds pipeline state from `MTLCompileOptions` source does this; it is not native CPU/machine-code generation and has no bearing on iOS's "no dynamically generated executable code" rule for CPU code).

- `gfx_metal_shader.cpp:203-283` (`gfx_metal_build_shader`) — uses the `prism::Processor` templating engine (also used by SoH's build-time HLSL/GLSL variants) to expand a `.metal` shader **template resource** (loaded from the `f3d.o2r` resource archive via `Ship::ResourceManager::LoadResource`, `gfx_metal_shader.cpp:264-265`) against the current `CCFeatures` bitfield (texture combine mode, fog, alpha, 2-cycle, etc.), producing a `std::string` of literal Metal Shading Language source text (`gfx_metal_shader.cpp:275`, `result = processor.process()`).
- `gfx_metal.cpp:217-303` (`CreateAndLoadNewShader`) — the actual compile call: `MTL::Library* library = mDevice->newLibrary(NS::String::string(buf.data(), NS::UTF8StringEncoding), nullptr, &error);` (`gfx_metal.cpp:229-230`). Errors reported via `error->localizedDescription()`. Then `library->newFunction("vertexShader")`/`"fragmentShader"` (`:237-238`) and `mDevice->newRenderPipelineState(pipeline_descriptor, &error)` per-MSAA-level (`:279`, looped over `mMsaaNumQualityLevels`, `:275-292`).
- A second, independent runtime-compiled Metal library exists for compute kernels: `gfx_metal.cpp:154-197` (`Init()`) — a hardcoded MSL string (`depth_shader`, `:154-181`, containing `depthKernel` and `convertToRGB5A1` compute kernels for depth-query and framebuffer-readback) compiled via the same `mDevice->newLibrary(...)` pattern (`:186-187`).
- **Shader caching:** in-process only. `mShaderProgramPool` (`gfx_metal.h:194-195`, keyed by `(shader_id0, shader_id1)`) caches compiled `ShaderProgramMetal` (which holds `MTL::RenderPipelineState*` per MSAA level, `gfx_metal.h:60-71`) for the lifetime of the process; `ClearShaderCache` (`gfx_metal.cpp:211-215`) marks entries for lazy deletion, `LookupShader` (`:305-320`) evicts marked entries on next miss. **No `MTLBinaryArchive` / disk-persisted pipeline cache exists anywhere in this backend** — every process start recompiles every combiner-shader variant it encounters from scratch via `newLibrary`. This is a legitimate but unaddressed cold-start/hitching concern for iOS (Metal shader compile is not free, and unlike macOS there's no OS-level shader cache equivalent to what some other platforms offer); not a *legality* blocker, but a perf item worth flagging for a real port.

**OpenGL backend's shader generation (for comparison):** `gfx_opengl.cpp` (functions building around the same `prism::Processor` + `CCFeatures` pattern, e.g. `BuildFsShader`/`BuildVsShader` — see excerpts at `gfx_opengl.cpp:270-378`) uses the identical templating strategy against a `.glsl` resource (`shaders/opengl/default.shader.glsl`, loaded the same way) and picks GLSL version/dialect via preprocessor branches:
  - `gfx_opengl.cpp:283-289` (fragment) / `:349-356` (vertex): `#ifdef __APPLE__` → `#version 410 core` (desktop GL 4.1 core, macOS-only ceiling — OpenGL on macOS never exceeds 4.1) with `opengles=false`.
  - `#elif defined(USE_OPENGLES)` → `#version 300 es` (**GLES3**, `precision mediump float` on the fragment variant) with `opengles=true`.
  - `#else` → `#version 130` (desktop GL 3.0-ish compat) for Linux/Windows.
  This is compiled the normal OpenGL way (`glCompileShader`/`glLinkProgram`, standard runtime GPU-shader compilation, same legality class as Metal's `newLibrary`). **However, this file is never built for iOS at all in this fork** — see A.5.

### A.4 ImGui backends and mobile-specific handling

- `cmake/dependencies/common.cmake:30-34` — `ImGui` target unconditionally gets `imgui_impl_opengl3.cpp` and `imgui_impl_sdl2.cpp` sources (all platforms, including iOS — this is a minor build-hygiene wrinkle: the OpenGL3 ImGui backend compiles into the `ImGui` static lib on iOS even though the LUS OpenGL *renderer* backend itself is excluded there, `src/fast/CMakeLists.txt:29-31`; not a functional blocker since it's never invoked, just extra compiled surface).
- `cmake/dependencies/ios.cmake:82-90` — additionally adds `imgui_impl_metal.mm` for iOS, defines `IMGUI_IMPL_METAL_CPP`, links `SDL2::SDL2-static`/`SDL2main`.
- `cmake/dependencies/mac.cmake:26-42` — same `imgui_impl_metal.mm` addition for Darwin, but links `SDL2::SDL2` (dynamic) instead, plus `GLEW`/`OpenGL` framework (for the desktop OpenGL fallback macOS still supports).
- Dispatch in `Fast3dGui.cpp`:
  - `Fast3dGui.cpp:88-117` (`ImGuiWMInit`) — `case WindowBackend::FAST3D_SDL_METAL:` under `#if __APPLE__` (`:97-105`) calls `ImGui_ImplSDL2_InitForMetal(...)`.
  - `Fast3dGui.cpp:53-66` (`SupportsViewports`) — `#if defined(__ANDROID__) || defined(__IOS__) return false;` — **multi-viewport (floating/detachable ImGui windows) is explicitly disabled on mobile**, sensible since iOS has no concept of separate OS-level windows for a game's debug UI.
  - `Fast3dGui.cpp:68-86` (`HandleWindowEvents`) — `#if defined(__ANDROID__) || defined(__IOS__)` (`:73-75`) calls `Ship::Mobile::ImGuiProcessEvent(ImGui::GetIO().WantTextInput)` after the normal `ImGui_ImplSDL2_ProcessEvent`.
  - `Fast3dGui.cpp:91,99` — `SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "1")` set for both OpenGL and Metal init paths — this is the actual touch-input handling mechanism: SDL translates touch events to synthetic mouse events, ImGui/game code doesn't need bespoke touch code.
- **`lus-pinned/src/ship/port/mobile/MobileImpl.cpp` (26 lines total, compiled only for `Android OR iOS`, `src/ship/CMakeLists.txt:97-101`):** this is the entirety of the dedicated mobile-input layer. `Ship::Mobile::ImGuiProcessEvent(bool wantsTextInput)` (`MobileImpl.cpp:9-25`) shows/hides the on-screen virtual keyboard via `SDL_StartTextInput()`/`SDL_StopTextInput()` when an ImGui text field gains/loses focus, and clears the ImGui input-text buffer on show. That's it — no custom touch-to-camera, virtual-joystick, or gesture code exists in LUS itself. (Any on-screen touch controls for actual gameplay, as opposed to the debug/config UI, would need to come from SoH-side game code, not this LUS layer — not investigated further here as out of scope for the rendering/JIT question.)
- Identical in `lus` main (same file, same 26 lines, same gating).

### A.5 OpenGL / GLES path — and the real per-platform backend-selection logic

- **iOS never builds the OpenGL backend at all.** `src/fast/CMakeLists.txt:29-31`:
  ```cmake
  if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
      list(FILTER Source_Files__Graphic EXCLUDE REGEX "graphic/Fast3D/backends/gfx_opengl*")
  endif()
  ```
  So `USE_OPENGLES`/GLES2-vs-GLES3 is **moot for iOS in this fork** — it only matters for Android (`USE_OPENGLES` links `GLESv3`, `src/CMakeLists.txt:123-126`, confirming **GLES3**, not GLES2) and OpenBSD (`OpenGL::GLES2`, `src/CMakeLists.txt:127-128`, i.e. that platform is GLES2). iOS gets Metal exclusively — no deprecated-but-functional GLES fallback path exists to fall back to on iOS in this codebase; it was deliberately never wired up.
- **Runtime backend selection** — `Fast3dWindow.cpp:24-40` (constructor): on `__APPLE__`, `if (Metal_IsSupported()) AddAvailableWindowBackend(WindowBackend::FAST3D_SDL_METAL);` is added **before** the unconditional `AddAvailableWindowBackend(WindowBackend::FAST3D_SDL_OPENGL)` (`:39`) — Metal is preferred/default on Apple platforms when available, OpenGL is the fallback (macOS only, since it's excluded from the iOS build entirely per above). `InitWindowManager()` (`Fast3dWindow.cpp:136-162`) then does the concrete `new GfxRenderingAPIMetal()` / `new GfxWindowBackendSDL2()` construction under `#ifdef __APPLE__` (`:152-157`) based on whatever backend `GetSavedWindowBackend()` resolved to.
- `gfx_sdl2.cpp:334-346`: on `__APPLE__`, `use_opengl = strcmp(gfxApiName, "OpenGL") == 0` (i.e. Metal is the default unless the user's config explicitly asks for `"OpenGL"`); everywhere else `use_opengl` is `constexpr true` (desktop-GL-or-GLES is the only option on non-Apple, non-Windows-DX11 platforms).
- **Verdict on GLES for iOS: not viable/not present as a fallback in this codebase** — it's excluded at the build-file level, not merely dormant. If Metal turned out to have a blocking bug on some iOS class of device, there is currently no compiled-in GLES escape hatch; one would have to be added (undo the `EXCLUDE REGEX` and wire GLES3 through `USE_OPENGLES` the same way Android does) rather than just flipped on. Given the storage-mode cleanliness and existing `__IOS__` branches already in `gfx_metal.cpp`, Metal-as-sole-iOS-backend looks like the intended design, not an oversight.

---

## (B) Runtime code generation — hard iOS blocker check

### B.1 Exhaustive pattern search

Searched actual repo trees (`soh/`, `lus-pinned/`, `lus/` — i.e. code that ships in the SoH binary as built by `soh/CMakeLists.txt`, **not** vendored/`FetchContent`-fetched third-party sources like TinyCC, which live outside these trees and are pulled at configure time):

```
grep -rn "PROT_EXEC|MAP_JIT|mprotect|VirtualProtect|VirtualAlloc" soh/ lus-pinned/  → 0 hits
grep -rln "asmjit|xbyak|dynarec|DynaRec"                          soh/ lus-pinned/  → 0 hits
```

**Zero self-modifying-code / raw-executable-memory patterns anywhere in the SoH or LUS source trees.** No dynarec, no JIT assembler libraries, no manual `mmap`+`PROT_EXEC`/`mprotect`+`PROT_EXEC` machinery.

**`dlopen`/`LoadLibrary` hits, classified:**

| Hit | File:line | Classification |
|---|---|---|
| `dlopen("libespeak-ng.so", ...)` | `soh/soh/soh/Enhancements/speechsynthesizer/ESpeakSpeechSynthesizer.cpp:9` | **Benign, optional, Linux-only.** Loads a system TTS shared library for accessibility narration. Explicitly excluded from the build on other platforms: `soh/soh/CMakeLists.txt:166` — `list(FILTER soh__ EXCLUDE REGEX "soh/Enhancements/speechsynthesizer/ESpeak")`. `.so` filename means it wouldn't resolve on iOS/macOS regardless. Would not be compiled into an iOS target. |
| `LoadLibraryA` in `portable-file-dialogs.h:208,801` | `soh/soh/soh/Extractor/portable-file-dialogs.h` | **Benign, Windows-only utility header** (loading system DLLs like `comdlg32`/`shell32` for native file-picker dialogs on Windows); guarded by the library's own `_WIN32` conditionals; irrelevant to non-Windows builds. |
| `dlopen`/`dlsym`/`LoadLibraryA`/`GetProcAddress` in `LibraryLoader.cpp` | `lus-pinned/src/ship/scripting/LibraryLoader.cpp:146,158,183,185` (and `lus` main, same file) | **Not benign in general, but gated off by default** — see B.1a below. This is the one real finding requiring a verdict caveat. |
| `dlopen` in `gfx_direct3d11.cpp`/`gfx_dxgi.cpp` | `lus-pinned/src/fast/backends/gfx_direct3d11.cpp`, `gfx_dxgi.cpp` | **Benign, Windows-only.** These files are excluded from non-Windows builds entirely (`src/fast/CMakeLists.txt:26-28`: `if (NOT CMAKE_SYSTEM_NAME STREQUAL "Windows") ... EXCLUDE REGEX "gfx_dxgi*"/"gfx_direct3d*"`). Not present in an iOS build at all. |

### B.1a — The one real dynamic-codegen subsystem: LUS's optional "TCC-based C mod scripting" — OFF by default, not enabled by SoH

This is the most important nuance for the hard-blocker question, and it did **not** show up in a naive `mprotect`/`PROT_EXEC` grep because it works differently: it compiles mod C code to a **file on disk** (a real `.dylib`/`.so`/`.dll`) via the bundled TinyCC (`libtcc`) compiler, then `dlopen`s that file — no raw RWX-memory JIT, but functionally identical in effect (arbitrary, unsigned, freshly-compiled native machine code executing in-process at runtime).

- `lus-pinned/CMakeLists.txt:12` — `option(ENABLE_SCRIPTING "Enable TCC-based C mod compilation and scripting system" OFF)` — **off by default.**
- `lus-pinned/CMakeLists.txt:11` — `option(DISABLE_DLL_LOADER "Disable dynamic library loading support" OFF)` — a *second*, independent kill-switch (only relevant if scripting is on).
- Gated compilation: `ScriptLoader.cpp`/`LibraryLoader.cpp`/`scriptingbridge.cpp` and their headers are all wrapped in `#ifdef ENABLE_SCRIPTING` (`ScriptLoader.cpp:3...363`, `LibraryLoader.h`, `scriptingbridge.cpp:3...12`, `Context.cpp:13,54,112,229,367,396,442`, `Context.h:26,178,250,290`) — when the CMake option is off, none of this code is even compiled into `libultraship`.
- `lus-pinned/src/ship/scripting/ScriptLoader.cpp:141-234` (`ScriptLoader::Compile`) — when a loaded `.o2r` archive declares a `Main` C-source script (mod manifest field) rather than a prebuilt per-platform binary: creates a `TCCState` (`tcc_new()`, `:141`), sets `TCC_OUTPUT_DLL` (`:164`), compiles the mod's C source via `tcc_compile_string` (`:225`), then **writes a real shared-library file to a temp path** via `tcc_output_file(s, temp.c_str())` (`:231`).
- `ScriptLoader.cpp:237` then calls `loader.Init(temp)` → `LibraryLoader::Init` (`LibraryLoader.cpp:143-175`) which `dlopen(path.c_str(), RTLD_NOW)` (`:158`) on non-Windows, or `LoadLibraryA` (`:146`) on Windows, then immediately `unlink()`s the temp file (`:167`) — classic "load then delete" pattern.
- `ScriptLoader.cpp:332,343` (`LoadAll`/`UnloadAll`) then `dlsym`s and calls `ModInit`/`ModExit` entry points from the freshly-loaded code (`GetFunction`, `LibraryLoader.cpp:177-191`).
- Also supports pre-supplied native binaries per-platform (`ScriptLoader.cpp:83` `GetPlatform()` — `ScriptLoader.cpp:44-79` **explicitly enumerates `"ios"` as a `GetPlatform()` return value** via `TARGET_OS_IPHONE`, `:52-58` — so this subsystem was written with iOS mod-binary distribution in mind at the API level, even though no toolchain/CI wires it up in this repo) — same `dlopen` load path either way.
- `common.cmake:155-308` shows the actual TinyCC (`libtcc`) build: fetched from `github.com/TinyCC/tinycc` (`:159-162`), built as a `SHARED` library (`:246`, LGPL-license reason given at `:243-245`), with explicit iOS cross-compile accommodations already present (`:186-189` disables `CONFIG_CODESIGN` for iOS targets; `:206` unsets `SDKROOT`/`IPHONEOS_DEPLOYMENT_TARGET` when building the host-side `c2str` tool; `:224-233` disables code-signing requirements for the `tcc_c2str` Xcode target on Apple). This confirms someone has already tried to make `ENABLE_SCRIPTING` cross-compile for iOS, at least partially, even though it isn't turned on by SoH.

**Is it enabled in SoH's shipped build?** No. `grep -rn "ENABLE_SCRIPTING" soh/` → **zero hits** anywhere in `soh/CMakeLists.txt` or `soh/soh/CMakeLists.txt`. SoH's top-level `CMakeLists.txt:196` does `add_subdirectory(libultraship ...)` with no CMake cache overrides for `ENABLE_SCRIPTING` or `DISABLE_DLL_LOADER`, so LUS's own default (`OFF`) stands. **As currently built, SoH does not compile the TCC scripting/mod-DLL system in at all — no runtime C compilation, no mod `dlopen`, in the shipped binary.**

**Verdict implication:** this is a real, load-bearing caveat on the codegen verdict, not a false alarm to wave away. If a future iOS port of this codebase (or a fork) ever flips `ENABLE_SCRIPTING` on, it introduces genuine runtime native-code generation + dynamic loading of arbitrary unsigned executable code — a hard App Store / iOS platform-security blocker (iOS forbids `dlopen` of unsigned/ad-hoc dylibs outside the signed app bundle, and forbids writable+executable memory outside narrow JIT-entitled contexts like JavaScriptCore). For an iOS port, this option must stay `OFF` and ideally the mod-DLL code path should be compiled out entirely (`ENABLE_SCRIPTING=OFF` already achieves that) or hard-disabled at the platform level so a downstream fork can't accidentally re-enable it for an App-Store-distributed build.

### B.2 Game code is AOT-compiled decomp source; Overlay_Load confirmed as a permanent no-op stub

- `soh/soh/src` contains the full N64 OoT decompilation's C source tree, compiled statically as part of the `soh` target (game logic, actors, scenes — this is standard decomp-project structure, not investigated file-by-file here since it's not in dispute; confirmed by presence of `soh/soh/src/code/`, `soh/soh/src/overlays/`, `soh/soh/include/z64actor.h`, etc., and by every actor/overlay symbol below being ordinary statically-compiled C functions).
- **`Overlay_Load` is a confirmed permanent stub returning `0`:** `soh/soh/src/code/code_800FC620.c:23-97`:
  ```c
  s32 Overlay_Load(uintptr_t vRomStart, uintptr_t vRomEnd, void* vRamStart, void* vRamEnd, void* allocatedVRamAddr) {
      return 0;
  #if 0
      ... [full original N64 overlay-DMA + relocation + icache-invalidation logic, dead-code'd out] ...
  #endif
  }
  ```
  The entire original implementation (DMA'ing an overlay `.text`/`.data`/`.rodata` segment from ROM, applying ELF-style relocations via `Overlay_Relocate`, clearing BSS, invalidating the instruction cache) is present only inside `#if 0`. Every call site — `code_800FC620.c` itself is called from `z_effect_soft_sprite.c:209`, `loadfragment2.c:13`, `z_kaleido_manager.c:28` — just gets a no-op back. This is corroborated by `z_kaleido_manager.c:6-18`, where the `KALEIDO_OVERLAY(name)` macro (originally expanding to a struct populated with `_ovl_##name##SegmentRomStart/End` linker symbols) has been redefined to `{ 0 }` (`z_kaleido_manager.c:12-13`), i.e. the overlay table entries are zeroed placeholders, not real ROM offsets — there is nothing left for `Overlay_Load` to meaningfully act on even if it weren't stubbed.
- **Actor dispatch table is fully static, function pointers into statically-linked code, no overlay indirection:** `soh/soh/include/tables/actor_table.h` — `DEFINE_ACTOR(En_Test, ACTOR_EN_TEST, ALLOCTYPE_NORMAL)` etc. (`:15` onward, ~470+ entries observed through line 60). `soh/soh/include/z64actor_enum.h:6-8`:
  ```c
  #define DEFINE_ACTOR_INTERNAL(_0, enum, _2) enum,
  #define DEFINE_ACTOR_UNSET(enum) enum,
  #define DEFINE_ACTOR(_0, enum, _2) DEFINE_ACTOR_INTERNAL(_0, enum, _2)
  ```
  i.e. `actor_table.h` is X-macro'd into a plain C `enum` in this header; elsewhere (not further chased here, out of scope) the same table is X-macro'd a second time to build the actual `ActorInit` struct array with `&EnTest_Init`/`&EnTest_Update`/etc. — ordinary statically-linked C function pointers into code the compiler emitted directly into the executable at build time, the modern decomp-project pattern that replaced the N64's dynamic overlay-loading entirely.

### B.3 `.otr`/`.o2r` archives — data only, no executable-code resource type

Full enumerated `ResourceType` surface across both LUS resource layers:
- `lus-pinned/include/ship/resource/ResourceType.h:15-21` (base/`Ship` layer): `Blob` ("OBLB"), `Json` ("JSON"), `Shader` ("SHAD"). Factories: `lus-pinned/src/ship/resource/factory/{JsonFactory,ShaderFactory,BlobFactory}.cpp`.
- `lus-pinned/include/fast/resource/ResourceType.h:5-13` (`Fast`/Fast3D layer): `DisplayList` ("ODLT"), `Light` ("LGTS"), `Matrix` ("OMTX"), `Texture` ("OTEX"), `Vertex` ("OVTX"). Factories: `lus-pinned/src/fast/resource/factory/{DisplayListFactory,LightFactory,MatrixFactory,TextureFactory,VertexFactory}.cpp`.

That's the complete built-in resource-type list. **All eight types are data** (opcode streams, matrices, vertex buffers, texture pixels, light structs, JSON, binary blobs, and shader *source text* — the `Shader` type holds the MSL/GLSL/HLSL template text consumed by `gfx_metal_shader.cpp`/`gfx_opengl.cpp` at A.3, not compiled machine code). There is no "Code"/"Executable"/"Native"/"DLL" resource type registered anywhere in LUS's own resource system.

`DisplayList` handling confirms the interpreted-data model: `lus-pinned/src/fast/resource/factory/DisplayListFactory.cpp` parses XML-declared display lists into `Gfx` opcode arrays (`renderModes` map at `:8-33` shows this is building a lookup table of N64 GBI render-mode constants, i.e. semantic data, not code) which `lus-pinned/src/fast/interpreter.cpp` walks and dispatches to a fixed, statically-compiled set of native C++ handler functions (one handler per GBI opcode) — this is the same "bytecode interpreter over data" pattern the whole Fast3D/HLE-graphics design uses, structurally incapable of executing attacker/mod-supplied native code through this path. (The one place actual native code *can* enter the process from a resource archive is the opt-in `ENABLE_SCRIPTING` mod-DLL path in B.1a, which is a completely separate subsystem from the eight `ResourceType`s above and is off by default.)

---

## Runtime-codegen verdict (plain statement)

**As SoH is actually built today (no `ENABLE_SCRIPTING`, no `DISABLE_DLL_LOADER` override — i.e. LUS defaults), there is no runtime code generation and no dynamic loading of arbitrary native code anywhere in the shipped binary.** All gameplay/actor/overlay logic is AOT-compiled, statically-linked C from the decomp source tree; `Overlay_Load` (the one place the original N64 code dynamically loaded and relocated executable overlay segments) is a hard-coded `return 0;` stub with the real implementation dead-code'd under `#if 0` (`soh/soh/src/code/code_800FC620.c:23-97`); the `.otr`/`.o2r` resource archives carry only 8 well-defined data resource types (display-list opcodes, textures, vertices, matrices, lights, JSON, blobs, shader *source text*) consumed by fixed native interpreter/renderer code, never executable payloads; and Metal/OpenGL shader compilation via `MTLDevice::newLibrary`/`glCompileShader` is ordinary, App-Store-legal runtime GPU-shader compilation (not CPU codegen). The **one** genuine dynamic-native-codegen subsystem in the codebase — LUS's TinyCC-based C mod-compiler + `dlopen` loader (`lus-pinned/src/ship/scripting/ScriptLoader.cpp` + `LibraryLoader.cpp`) — is gated behind `ENABLE_SCRIPTING`, which defaults `OFF` and is never turned on anywhere in SoH's CMake configuration; it is simply not compiled into the SoH binary. It must be kept off (and ideally hard-disabled, not just left at its default) for any iOS build/distribution of this codebase, since if enabled it would be a hard App Store / iOS code-signing blocker.

---
