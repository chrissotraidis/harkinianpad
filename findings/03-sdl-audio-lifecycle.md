# SDL2 / Audio / Threading / Lifecycle Inventory — libultraship (pinned) + Ship of Harkinian

Trees used:
- `lus-pinned` = `/tmp/.../scratchpad/lus-pinned` (PRIMARY — what SoH actually builds against)
- `lus` = `/tmp/.../scratchpad/lus` (libultraship main, compared for drift)
- `soh` = `/tmp/.../scratchpad/soh`

Builds on prior sibling finding: `__IOS__`/`__ANDROID__` branches already exist at Context.cpp,
Fast3dWindow.cpp:77, Fast3dGui.cpp:23/61/73, and `src/ship/port/mobile/MobileImpl.cpp`. This
investigation additionally found a **third, more load-bearing layer of prior iOS work**: a full
CMake dependency/toolchain setup for iOS (`cmake/dependencies/ios.cmake`,
`cmake/ios-toolchain-populate.cmake`), described in section (A)3 below. SoH's own CMake
(`soh/CMakeLists.txt`, `soh/soh/CMakeLists.txt`) has **zero** iOS references — the iOS prep is
entirely inside the LUS engine layer, not the game/app layer.

---

## (A) SDL2 usage inventory

### A1. Inventory by subsystem

Full symbol frequency dump generated via
`grep -rhoE 'SDL_[A-Za-z_]+' lus-pinned/src soh/soh soh/src | sort | uniq -c | sort -rn`
(274 distinct symbols). Files touching `SDL_` at all:

```
lus-pinned/src/libultraship/window/gui/GfxDebuggerWindow.cpp
lus-pinned/src/libultraship/controller/controldeck/ControlDeck.cpp
lus-pinned/src/libultraship/controller/controldevice/controller/Controller.cpp
lus-pinned/src/libultraship/controller/controldevice/controller/mapping/ControllerDefaultMappings.cpp
lus-pinned/src/libultraship/libultra/os.cpp
lus-pinned/src/libultraship/libultra/os_vi.cpp
lus-pinned/src/ship/debug/CrashHandler.cpp
lus-pinned/src/ship/audio/SDLAudioPlayer.cpp
lus-pinned/src/ship/port/mobile/MobileImpl.cpp
lus-pinned/src/ship/Context.cpp
lus-pinned/src/ship/controller/controldevice/controller/Controller.cpp
lus-pinned/src/ship/controller/controldevice/controller/mapping/ControllerDefaultMappings.cpp
lus-pinned/src/ship/controller/controldevice/controller/mapping/sdl/*.cpp  (8 files: Button/Axis/Gyro/LED/Rumble mappings)
lus-pinned/src/ship/controller/controldevice/controller/mapping/factories/*.cpp (5 files)
lus-pinned/src/ship/controller/physicaldevice/SDLAddRemoveDeviceEventHandler.cpp
lus-pinned/src/ship/controller/physicaldevice/ConnectedPhysicalDeviceManager.cpp
lus-pinned/src/ship/utils/macUtils.mm
lus-pinned/src/fast/Fast3dGui.cpp
lus-pinned/src/fast/backends/gfx_sdl2.cpp        <- window/GL/event pump core
lus-pinned/src/fast/backends/gfx_metal.cpp       <- Metal-via-SDL_Renderer
lus-pinned/src/fast/Fast3dWindow.cpp
soh/soh/src/code/main.c                          <- SDL_main / main()
soh/soh/soh/Extractor/Extract.cpp                <- (pfd, documented by sibling agent)
soh/soh/soh/OTRGlobals.cpp                        <- main render/event loop glue
soh/soh/soh/Network/Network.h
soh/soh/soh/SohGui/SohMenuSettings.cpp
soh/soh/soh/SohGui/BackendTypes.h
soh/soh/CMakeLists.txt
```

**Window/GL/Metal creation & lifecycle** — `lus-pinned/src/fast/backends/gfx_sdl2.cpp`:
- `SDL_Init(SDL_INIT_VIDEO)` — gfx_sdl2.cpp:330
- `SDL_CreateWindow(...)` with per-platform flags — gfx_sdl2.cpp:373-388 (see A2)
- `SDL_GL_SetAttribute` (depth/stencil/doublebuffer/core-profile 4.1) — gfx_sdl2.cpp:341-352
- `SDL_GL_CreateContext` / `SDL_GL_MakeCurrent` / `SDL_GL_SetSwapInterval` — gfx_sdl2.cpp:414-417
- `SDL_CreateRenderer` (Metal path, `SDL_RENDERER_ACCELERATED`) — gfx_sdl2.cpp:422-426
- `SDL_GL_SwapWindow` — gfx_sdl2.cpp:750 (called every frame from `SwapBuffersBegin`)
- `SDL_DestroyWindow` / `SDL_DestroyRenderer` / `SDL_GL_DeleteContext` / `SDL_Quit` — gfx_sdl2.cpp:786-789
- Metal layer retrieval: `SDL_RenderGetMetalLayer(renderer)` — `lus-pinned/src/fast/backends/gfx_metal.cpp:79`

**Events** — `gfx_sdl2.cpp:605-686` (`HandleSingleEvent`/`HandleEvents`):
- `SDL_PumpEvents` + double `SDL_PeepEvents` split around controller-add/remove range — gfx_sdl2.cpp:666-674
- Handles: `SDL_KEYDOWN/UP`, `SDL_MOUSEBUTTONDOWN/UP`, `SDL_MOUSEWHEEL`, `SDL_WINDOWEVENT` (`SIZE_CHANGED`, `CLOSE`), `SDL_DROPFILE`, `SDL_QUIT` — gfx_sdl2.cpp:619-663
- Called every frame from two sites in `soh/soh/soh/OTRGlobals.cpp:714` (pre-launch extractor UI loop) and `OTRGlobals.cpp:1784` (`RunCommands`, the real gameplay per-frame path)

**Gamecontroller/Joystick** — spread across `ship/controller/controldevice/controller/mapping/sdl/*` and `ship/controller/physicaldevice/ConnectedPhysicalDeviceManager.cpp` (detailed in A4).

**Haptic/Rumble**: `SDL_GameControllerRumble` — `SDLRumbleMapping.cpp:20,29`; `SDL_GameControllerHasRumble` referenced (RumbleMappingFactory).

**LED**: `SDL_GameControllerHasLED` / `SDL_JoystickSetLED` — `SDLLEDMapping.cpp:26,29`.

**Gyro/Sensors**: `SDL_GameControllerHasSensor(gamepad, SDL_SENSOR_GYRO)`, `SDL_GameControllerSetSensorEnabled`, `SDL_GameControllerGetSensorData` — `SDLGyroMapping.cpp:24-31,53-60`.

**Audio**: `SDL_OpenAudioDevice`, `SDL_QueueAudio`, `SDL_PauseAudioDevice`, `SDL_ClearQueuedAudio`, `SDL_CloseAudioDevice`, `SDL_GetQueuedAudioSize` — all in `lus-pinned/src/ship/audio/SDLAudioPlayer.cpp` (see B1). No `SDL_AudioCallback` used — it's the queue-based (`SDL_QueueAudio`) API, not callback-based (`want.callback = NULL` at `SDLAudioPlayer.cpp:38`).

**Hints**: `SDL_SetHint(SDL_HINT_WINDOWS_DPI_AWARENESS, ...)` (Windows-only, gated `SDL_VERSION_ATLEAST(2,24,0)`) — gfx_sdl2.cpp:327; `SDL_SetHint(SDL_HINT_RENDER_DRIVER, "metal")` — gfx_sdl2.cpp:345; `SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS`, `SDL_HINT_TOUCH_MOUSE_EVENTS`, `SDL_HINT_MOUSE_RELATIVE_MODE_CENTER`, `SDL_HINT_JOYSTICK_THREAD` referenced elsewhere in controller code.

**Clipboard**: `SDL_SetClipboardText` — `lus-pinned/src/libultraship/window/gui/GfxDebuggerWindow.cpp:72,76` only (a debug/dev tool window — copies a hex address/value to clipboard). Not part of core gameplay flow.

**Mouse**: `SDL_SetRelativeMouseMode`, `SDL_GetRelativeMouseMode`, `SDL_GetRelativeMouseState`, `SDL_WarpMouseInWindow`, `SDL_GetMouseState`, `SDL_SetWindowMouseRect`/`SDL_GetWindowMouseRect`, `SDL_ShowCursor` — all in `gfx_sdl2.cpp:466-513` (see A2 for iOS relevance).

**Keyboard**: Full `SDL_SCANCODE_*` translation table `gfx_sdl2.cpp:56-212` (LUS-internal scancode <-> SDL scancode mapping table, ~130 entries) — this is a static compatibility table, not itself an iOS issue since it's just an ID mapping used opportunistically when a hardware keyboard/virtual keyboard sends key events.

**Prefpath**: `SDL_GetPrefPath` referenced (config path resolution) but overridden by `__ANDROID__`/`__IOS__` branches in `Context.cpp:460-534` (see A-mobile section) which use `SDL_AndroidGetExternalStoragePath()` / `getenv("HOME")+"/Documents"` respectively instead.

**Timer/perf**: `SDL_GetPerformanceCounter`, `SDL_GetPerformanceFrequency` — used for the custom frame-pacing sleep loop in `gfx_sdl2.cpp:692-738` (`SyncFramerateWithTime`), not `SDL_Delay`/`SDL_AddTimer`. `SDL_AddTimer` appears once in the codebase-wide symbol count but is Windows/CrashHandler-related, not core loop.

### A2. iOS-problematic usages flagged

1. **Window flags** — `gfx_sdl2.cpp:376-380`: already branches on `__IOS__` (uses `SDL_WINDOW_BORDERLESS | SDL_WINDOW_SHOWN`, no `SDL_WINDOW_RESIZABLE`), vs. desktop's `SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI`. This is correct/expected for iOS (fixed-size fullscreen UIKit window) — **already handled**.
2. **`SDL_SetWindowSize`/`SDL_SetWindowPosition`** — `gfx_sdl2.cpp:267-268` (in `SetFullscreenImpl`, un-fullscreen path) and `gfx_sdl2.cpp:540-541` (`SetDimensions`). Not gated for iOS. On iOS these are effectively no-ops/undesired since the window always fills the screen; harmless if never invoked (the fullscreen-toggle keybind path in `Fast3dWindow.cpp:347-353` is keyboard-driven, so unreachable without a hardware keyboard) but should be no-op-guarded for iOS defensively.
3. **`SDL_SetWindowFullscreen(..., SDL_WINDOW_FULLSCREEN_DESKTOP / SDL_WINDOW_FULLSCREEN)`** — `gfx_sdl2.cpp:245-249`, gated `#if !defined(__APPLE__)` at the block level (macOS uses native fullscreen APIs via `isNativeMacOSFullscreenActive`/`toggleNativeMacOSFullscreen`, `gfx_sdl2.cpp:238-243`). **iOS falls into the `#if !defined(__APPLE__)` == false branch too** (iOS defines `__APPLE__`), so it goes through the macOS-native-fullscreen code path (`macUtils.mm`), which is almost certainly wrong for iOS (there is no `NSWindow`/native-fullscreen concept on UIKit). This needs an explicit `__IOS__` carve-out. Flag: **needs fix**, `gfx_sdl2.cpp:238-256` and `lus-pinned/src/ship/utils/macUtils.mm`.
4. **`SDL_SetRelativeMouseMode`/mouse capture** — `gfx_sdl2.cpp:497-513` (`SetMouseCapture`/`IsMouseCaptured`). Consumer: `soh/soh/soh/Enhancements/controls/Mouse.cpp:16` (`MOUSE_ENABLED` macro gated by `CVAR_ENABLE_MOUSE_VALUE && GetWindow()->IsMouseCaptured()`) — this is an **opt-in PC "mouse-look" Enhancement**, not core gameplay. Toggled via keybind `Ship::KbScancode::LUS_KB_F2` (`Fast3dWindow.cpp:100-101,352-354`) — keyboard-only entry point, effectively unreachable/moot on iOS (no keyboard-driven toggle without a hardware keyboard; the CVar defaults off). Not a blocker, just dead weight on iOS.
5. **`SDL_ShowCursor`** — `gfx_sdl2.cpp:466-472`. No-op-safe on iOS (SDL2 iOS backend accepts these calls harmlessly), not a real problem.
6. **Display-index handling** — `SDL_GetWindowDisplayIndex`, `SDL_GetDesktopDisplayMode`, `SDL_GetCurrentDisplayMode` used throughout `gfx_sdl2.cpp` (`SetFullscreenImpl:222-236`, `GetActiveWindowRefreshRate:276-282`, `GetPrimaryMonitorRect:545-557`, `Init:401-405`). Single-display assumption is fine for iOS (always display index 0), but none of this is iOS-gated; should be harmless since iOS always reports one display.
7. **Clipboard** — confined to the debug `GfxDebuggerWindow.cpp` dev tool, not core-path. Non-issue.
8. **Native file dialogs outside the extractor**: none found. `grep -rln "portable-file-dialogs|pfd::|tinyfd|nfdresult|NFD::|NFD_Open" lus-pinned/src lus-pinned/include soh/soh soh/src` returns only `soh/soh/soh/Extractor/Extract.cpp` and the vendored header `soh/soh/soh/Extractor/portable-file-dialogs.h` — confirmed no other native-dialog usage (matches sibling agent's extractor-only finding).

### A3. SDL version

**Pinned SDL2 tag, per platform** (`lus-pinned/cmake/dependencies/*.cmake`, `GIT_REPOSITORY https://github.com/libsdl-org/SDL.git`):
- **iOS** (`ios.cmake:6-13`): `GIT_TAG release-2.32.10` (`FetchContent`, `OVERRIDE_FIND_PACKAGE`)
- **Android** (`android.cmake:7-9`): `GIT_TAG release-2.32.10` (same)
- **macOS** (`mac.cmake`): `find_package(SDL2 REQUIRED)` (system/Homebrew SDL2, version not pinned in-repo)
- **Linux** (`linux.cmake:2`): `find_package(SDL2 REQUIRED)` (system SDL2)
- **Windows** (`windows.cmake:8`): `find_package(SDL2 CONFIG REQUIRED)` (vcpkg-provided)

So iOS already has a concrete, modern SDL2 pin: **2.32.10**. This comfortably exceeds every API-level constraint found in the code:
- `SDL_VERSION_ATLEAST(2, 24, 0)` gate at `gfx_sdl2.cpp:325` (Windows DPI hint) — met.
- `SDL_SetWindowMouseRect`/`SDL_GetWindowMouseRect` (added SDL 2.0.18) — met, used unconditionally `gfx_sdl2.cpp:502-508`.
- `SDL_GameControllerHasRumble` (added SDL 2.0.18) — met.
- `SDL_GameControllerHasLED`/`SDL_JoystickSetLED` (added SDL 2.0.14) — met.
- Gyro sensor API (`SDL_GameControllerHasSensor`/`GetSensorData`, added SDL 2.0.14) — met.
- `SDL_RenderGetMetalLayer` (added SDL 2.0.8, Metal renderer) — met.

**lus main (non-pinned) tree**: `lus/cmake/dependencies/` has the exact same file set as `lus-pinned/cmake/dependencies/` (`diff` of directory listings is empty) — confirms **lus main is also still SDL2**, not SDL3; the iOS SDL2 2.32.10 pin is present and identical there too. No SDL3 migration underway.

**iOS toolchain**: `lus-pinned/cmake/ios-toolchain-populate.cmake` — fetches `leetal/ios-cmake` (pinned commit `06465b27698424cf4a04a5ca4904d50a3c966c45`), sets `PLATFORM=OS64COMBINED`. Standard, well-known CMake iOS toolchain. Invoked from `lus-pinned/CMakeLists.txt:76-78` only `if(CMAKE_SYSTEM_NAME STREQUAL "iOS")`.

**iOS dependency set** (`ios.cmake`): SDL2 2.32.10, nlohmann-json 3.12.0, tinyxml2 11.0.0, spdlog 1.16.0, libzip 1.11.4 (static), plus `metal-cpp` single-header (`briaguya-ai/single-header-metal-cpp`, tag `macOS13_iOS16`) and ImGui's `imgui_impl_metal.mm` backend wired in (`ios.cmake:82-90`) — i.e. **the iOS build is Metal-only** (no OpenGL ES path configured), consistent with `Fast3dWindow.cpp:34-39` which only registers `FAST3D_SDL_METAL` for `__APPLE__` (checked via `Metal_IsSupported()`) plus the unconditional `FAST3D_SDL_OPENGL` fallback registration — worth verifying `ENABLE_OPENGL` isn't also compiled in for iOS since `gfx_sdl2.cpp:1` is gated `#if defined(ENABLE_OPENGL) || defined(__APPLE__)`, meaning gfx_sdl2.cpp itself always compiles on Apple platforms regardless of `ENABLE_OPENGL`.

### A4. Controllers

**Stack**: `ship/controller/physicaldevice/ConnectedPhysicalDeviceManager.{h,cpp}` owns the live `SDL_GameController*` map, keyed by SDL joystick instance ID, refreshed via `RefreshConnectedSDLGamepads()` (`ConnectedPhysicalDeviceManager.cpp:51-90ish`), driven by `SDL_NumJoysticks`, `SDL_JoystickGetDeviceGUID`, `SDL_IsGameController`, `SDL_GameControllerOpen`. Hook-up on connect/disconnect: `HandlePhysicalDeviceConnect`/`HandlePhysicalDeviceDisconnect` (`ConnectedPhysicalDeviceManager.cpp:44-49`), fed by `SDLAddRemoveDeviceEventHandler.cpp` reacting to `SDL_CONTROLLERDEVICEADDED`/`SDL_CONTROLLERDEVICEREMOVED` events (split out specially in the event pump, `gfx_sdl2.cpp:669,672`).

**Mapping classes**, all `ship/controller/controldevice/controller/mapping/sdl/`:
- `SDLButtonToButtonMapping.cpp`, `SDLButtonToAnyMapping.cpp`, `SDLButtonToAxisDirectionMapping.cpp` — digital button mapping
- `SDLAxisDirectionToAxisDirectionMapping.cpp`, `SDLAxisDirectionToButtonMapping.cpp`, `SDLAxisDirectionToAnyMapping.cpp` — analog stick/trigger mapping
- `SDLRumbleMapping.cpp` — `SDL_GameControllerRumble(gamepad, low, high, 0)` (`:20`), stop via `(0,0,0)` (`:29`)
- `SDLGyroMapping.cpp` — `SDL_GameControllerHasSensor(gamepad, SDL_SENSOR_GYRO)` (`:24`), `SDL_GameControllerSetSensorEnabled` + `SDL_GameControllerGetSensorData` (`:29-31`, `:60-62`)
- `SDLLEDMapping.cpp` — `SDL_GameControllerHasLED`/`SDL_JoystickSetLED` (`:26,29`)
- Factories (`ship/controller/controldevice/controller/mapping/factories/*.cpp`) instantiate the above from saved config.

**No raw hidapi / manufacturer SDK usage anywhere**: `grep -rln "hidapi|hid_init|hid_open"` across both trees returns nothing. Everything routes through `SDL_GameController`, which SDL2's iOS backend implements on top of Apple's `GameController.framework` (MFi controllers, PS4/PS5/Xbox controllers via Bluetooth, plus the on-screen `GCVirtualController` in newer SDL2 — version-dependent). Rumble/gyro/LED all map onto `GCController` capabilities that iOS's `GameController.framework` exposes for MFi-class controllers (rumble via `GCHapticsController` starting iOS 14, gyro via `GCMotion`, LED is Switch-JoyCon-specific and effectively moot on iOS since JoyCons aren't first-class iOS-supported controllers). **Verdict: controller stack is iOS-clean, no porting blockers.**

**Keyboard dependence**: The one place keyboard usage gates a *feature toggle* rather than gameplay is the mouse-capture and fullscreen keybinds (`Fast3dWindow.cpp:99-101, 347-354`, hard-coded default scancodes `LUS_KB_F11`/`LUS_KB_F2`). Core gameplay input flows entirely through `ControlDeck::ProcessKeyboardEvent` OR the controller/gamepad mapping path symmetrically (`ControlDeck.cpp`) — no flow found that is keyboard-*only* for actual gameplay. Menu/UI navigation via ImGui gamepad nav is supported (`ImGuiConfigFlags_NavEnableGamepad`, toggle at `lus-pinned/src/ship/window/gui/Gui.cpp:91,93,131,135,141,218,220` and `soh/soh/soh/SohGui/Menu.cpp:820,822`) — this is the mechanism that would let a controller-only iOS session (Bluetooth/MFi controller, no on-screen touch UI) drive the settings menus.

**Virtual keyboard**: `MobileImpl.cpp` (`__ANDROID__`/`__IOS__` gated) hooks `SDL_StartTextInput`/`SDL_StopTextInput` based on ImGui's `WantTextInput`, driven from `Fast3dGui.cpp:73-75` inside the SDL event dispatch path. This is the existing text-entry affordance for touch keyboards.

---

## (B) Audio

### B1. Backend(s) — `lus-pinned/src/ship/audio/`

Four `AudioPlayer` subclasses, selected in `Audio::InitAudioPlayer()` (`Audio.cpp:17-42`) via `Audio::GetCurrentAudioBackend()`:
- `WasapiAudioPlayer` — Windows only (`#ifdef _WIN32`, `Audio.cpp:19-22`)
- `CoreAudioAudioPlayer` — Apple only (`#ifdef __APPLE__`, `Audio.cpp:24-27`) — **default backend on all `__APPLE__` targets** (`Audio.cpp:100-102`, `GetSavedAudioBackend()`'s fallback when no config value is set)
- `SDLAudioPlayer` — all platforms (`Audio.cpp:29-31`)
- `NullAudioPlayer` — fallback when the selected backend's `Init()` fails (`Audio.cpp:37-41`)

**`SDLAudioPlayer`** (`SDLAudioPlayer.cpp`): queue-based, not callback-based — `want.callback = NULL` (`:38`), audio pushed via `SDL_QueueAudio(mDevice, buf, len)` in `DoPlay` (`:59`), gated `if (Buffered() < 6000)` samples. Format: `AUDIO_S16SYS` (`:35`), channels from `GetNumOutputChannels()` (2 or 6) (`:30,36`), `want.freq = GetSampleRate()` and `want.samples = GetSampleLength()` (`:34,37`) — these come from `AudioSettings` defaults in `lus-pinned/include/ship/audio/AudioPlayer.h:15-17`: **`SampleRate = 44100`, `SampleLength = 1024`, `DesiredBuffered = 2480`** (all hardcoded defaults, overridable via `AudioSettings`). Device opened with `SDL_OpenAudioDevice(NULL, 0, &want, &have, 0)` — last arg `0` means **no `SDL_AUDIO_ALLOW_*_CHANGE` flags**, i.e. it demands the exact requested format rather than negotiating (`:40`).

**`CoreAudioAudioPlayer`** (`CoreAudioAudioPlayer.cpp`, `#ifdef __APPLE__` only, no `TARGET_OS_IPHONE`/`TARGET_OS_IOS` sub-guard): builds an `AudioComponentDescription` with `componentSubType = kAudioUnitSubType_HALOutput` (`:47`). **This is macOS-only** — `kAudioUnitSubType_HALOutput` (AUHAL) is not available on iOS; iOS requires `kAudioUnitSubType_RemoteIO` plus an `AVAudioSession` category/activation call, neither of which is present here. Since this file is gated only by `__APPLE__` (true for iOS too) and is the *default* backend selection for `__APPLE__` (`Audio.cpp:100-102`), **as written this would either fail to find the AudioComponent at runtime on iOS (`AudioComponentFindNext` returns `NULL`, `CoreAudioAudioPlayer.cpp:52-56`, causing `DoInit()` to return `false`) or fail to compile if `kAudioUnitSubType_HALOutput` isn't declared for the iOS SDK target.** Either way, `Audio::InitAudioPlayer()`'s fallback logic (`Audio.cpp:37-41`) would silently drop to `NullAudioPlayer` (silence) rather than crash — but that means **iOS builds today would ship silent audio unless this is fixed**: either add a `RemoteIO`+`AVAudioSession` variant gated on iOS, or exclude iOS from the `AudioBackend::COREAUDIO` default/availability list (`Audio.cpp:51-53` unconditionally appends `COREAUDIO` to `mAvailableAudioBackends` for any `__APPLE__`) and let it fall through to `SDLAudioPlayer`, which is otherwise platform-generic and would work as-is via SDL2's iOS `AVAudioSession`-backed audio implementation.

Ring buffer in `CoreAudioAudioPlayer` is a manual `uint8_t*` circular buffer guarded by `pthread_mutex_t` (`:9,15,116-161`), fed from the render callback `CoreAudioRenderCallback` (`:163-209`) — architecture itself (ring buffer + render-callback pull model) is portable to a RemoteIO-based iOS variant if someone wants to fix it that way instead of relying on SDL.

**Sound-matrix/5.1 decoding**: `SoundMatrixDecoder` engaged only for `AudioChannelsSetting::audioMatrix51` (`AudioPlayer.cpp:12-14,67-76,90-107`) — not iOS-relevant (stereo default).

### B2. Interruption / route-change / background handling

**Confirmed absent.** Full-tree search for `AVAudioSession`, `SDL_iPhoneSetAnimationCallback`, `SDL_iPhoneSetEventPump`, and every `SDL_APP_*` lifecycle event constant (`SDL_APP_WILLENTERBACKGROUND`, `SDL_APP_DIDENTERBACKGROUND`, `SDL_APP_WILLENTERFOREGROUND`, `SDL_APP_DIDENTERFOREGROUND`, `SDL_APP_LOWMEMORY`, `SDL_APP_TERMINATING`) across `lus-pinned` and `soh` returns **zero matches**. No audio-route-change (headphones unplugged, Bluetooth reconnect), no interruption (phone call, Siri, alarm), no background-audio handling of any kind exists today.

**What iOS would need**: SDL2's built-in iOS layer already posts `SDL_APP_WILLENTERBACKGROUND`/`SDL_APP_DIDENTERBACKGROUND`/etc. as ordinary `SDL_Event`s through the normal event queue (no extra API needed to *receive* them — `SDL_PollEvent`/`SDL_PeepEvents` in `gfx_sdl2.cpp:666-674` would surface them automatically) — but `HandleSingleEvent`'s `switch (event.type)` (`gfx_sdl2.cpp:619-663`) has no `case` for any of them, so **today they're received and silently dropped**. To support suspend/resume properly, this switch needs new cases to: pause `SDLAudioPlayer`/`CoreAudioAudioPlayer` device (`SDL_PauseAudioDevice(mDevice, 1)` already exists as a method, just needs a trigger — `SDLAudioPlayer.cpp:15,48`), stop the render loop from spinning (see C2/C3), and force a `GetConfig()->Save()`/save-state flush (see C3) since the app can be killed without notice while suspended. Route-change/interruption handling would additionally need an `AVAudioSession` interruption observer wired in from Objective-C++ (there's already a precedent for `.mm` Apple-only glue at `lus-pinned/src/ship/utils/macUtils.mm`), independent of SDL, since SDL2 doesn't surface `AVAudioSession` interruptions as SDL events.

### B3. SoH audio thread / producer-consumer — `soh/soh/soh/OTRGlobals.cpp`

**Thread creation**: `audio.thread = std::thread(OTRAudio_Thread)` — `OTRGlobals.cpp:1126`, started from `OTRAudio_Init()` (`:1120-1128`) guarded by `audio.running` bool. Shutdown: `OTRAudio_Exit()` (`:1137-1146`) sets `audio.running = false` under `audio.mutex`, notifies `audio.cv_to_thread`, then `audio.thread.join()` (`:1146`).

**Producer/consumer scheme**: classic condvar-gated producer running on its own real `std::thread` (`OTRAudio_Thread`, `:1022-1118`):
- Consumer signal: `Graph_ProcessGfxCommands` (the per-frame render/gfx bridge, called from the main render loop) sets `audio.processing = true` under `audio.mutex` and calls `audio.cv_to_thread.notify_one()` — `OTRGlobals.cpp:1805-1809`.
- Producer loop: waits on `audio.cv_to_thread` (blocking pre-"primed", `wait_for` with a 5 ms self-pump timeout once primed, `:1074-1082`) so a stalled render thread can't starve the audio backend's queue; generates PCM via `AudioMgr_CreateNextAudioBuffer` and pushes via `AudioPlayer_Play` (`produce_next_batch` lambda, `:1038-1054`); includes a "producer guard" that skips advancing the N64 audio engine if the backend ring buffer is already near capacity, to avoid audible discontinuities (`:1093-1103`, referencing a fixed upstream bug `banteg/Shipwright#6594`); a pre-buffer top-up loop (`:1111-1116`) that keeps filling while the backend can accept more, decoupled from frame rate — explicitly designed (per the comment at `:1106-1109`) to be safe for BGM even under load spikes.
- Tempo-correctness comment at `:1029-1033` — sample count must average exactly `32000/60 = 533.33`/update or N64 sequencer tempo drifts; implemented via `sample_debt_thirds` fractional accumulator (`:1034,1039-1040`).

This design is backend-agnostic (talks to `AudioPlayer_Play`/`AudioPlayer_Buffered`/`AudioPlayer_GetDesiredBuffered` C-bridge functions, not SDL directly) — **the producer thread itself needs no iOS-specific change**; only the backend it feeds into (B1/B2) needs iOS work, plus this thread should be paused (not necessarily torn down) on background/suspend so it doesn't spin producing audio into a backend that's no longer able to play it (or, per Apple's background-audio rules, deliberately kept alive with `AVAudioSession` background-audio category if music-during-background is desired — a product decision, not just an engineering one).

---

## (C) Threading and lifecycle

### C1. Thread inventory

Real OS threads (`std::thread`/`BS::thread_pool`) found across both trees:

| Site | Purpose |
|---|---|
| `lus-pinned/src/ship/resource/ResourceManager.cpp:61` | `BS::thread_pool` sized `hardware_concurrency() - reservedThreadCount - 1` (min 1) — parallel resource/archive loading (`ResourceManager.cpp:59-61`) |
| `soh/soh/soh/OTRGlobals.cpp:454` | `BS::thread_pool(1)` — single background worker driving the ROM-extraction task in `RunExtract()`'s pre-launch UI loop |
| `soh/soh/soh/OTRGlobals.cpp:1126` | `std::thread(OTRAudio_Thread)` — the real-time audio producer thread (see B3) |
| `soh/soh/soh/SaveManager.cpp:129` | `BS::thread_pool(1)` (`smThreadPool`) — save I/O off the main path |
| `soh/soh/soh/Enhancements/randomizer/randomizer.cpp:967` | `std::thread(&GenerateRandomizerImgui, seed)` — randomizer seed generation |
| `soh/soh/soh/Network/Network.cpp:22` | `std::thread(&Network::ReceiveFromServer, this)` — multiplayer/network receive loop |
| `soh/soh/soh/Network/CrowdControl/CrowdControl.cpp:20` | `std::thread(&CrowdControl::ProcessActiveEffects, this)` — Crowd Control integration |
| `soh/soh/soh/resource/importer/AudioSampleFactory.cpp:313,317,321` | Per-file `std::thread` for MP3/Ogg/FLAC decode workers |

**Fiber/cooperative "N64 threads" (not real OS threads)**: `soh/soh/src/libultra/os/createthread.c` and `startthread.c` reimplement libultra's `osCreateThread`/`osStartThread` as a **cooperative, priority-based scheduler** (`__osRunQueue`/`__osActiveQueue`/`__osEnqueueAndYield`, `startthread.c:9-31`) — these are longjmp/context-switch-style fibers multiplexed onto **one real thread**, not genuine OS threads. Confirmed by `soh/soh/src/code/main.c:137-141`: `osCreateThread(&sGraphThread, ...)` followed immediately by `osStartThread(&sGraphThread); ...; Graph_ThreadEntry(0);` called **directly/synchronously** on the same call stack — i.e. the "graph thread", "audio mgr thread" (N64-side, distinct from the real `OTRAudio_Thread` above), "pad mgr thread", "sched thread", "irq mgr thread" are all fibers cooperatively scheduled within the **one real thread that called `main()`**.

**Who owns the main loop**: `soh/soh/src/code/main.c:59-72` (`main()`/`SDL_main()` on Windows) calls `Heaps_Alloc(); Main(0); DeinitOTR(); Heaps_Free();`. `Main()` (`main.c:74-159`) sets up the N64-emulation heaps/queues, starts the graph fiber synchronously (`main.c:137-141`), then **blocks forever** on `osRecvMesg(&irqMgrMsgQ, ..., OS_MESG_BLOCK)` (`main.c:143-153`) — this is dead code in practice for quit-handling since the real exit path is a direct `exit(0)` call (see C3), not this message queue.

The actual **per-frame blocking loop** is `soh/soh/src/code/graph.c:519-523`:
```c
void Graph_ThreadEntry(void* arg0) {
    while (WindowIsRunning()) {
        RunFrame();
    }
}
```
`RunFrame()` (`graph.c:482-517`) calls `Graph_StartFrame()`, `PadMgr_ThreadEntry()`, `Graph_Update()`, then `Graph_ProcessGfxCommands()` (`graph.c:497`) which is the C→C++ bridge into `soh/soh/soh/OTRGlobals.cpp:1800+` — ultimately reaching `RunCommands()` (`OTRGlobals.cpp:1772-1798`) which calls `wnd->HandleEvents()` (SDL event pump, `:1784`) and `wnd->DrawAndRunGraphicsCommands(...)` (`Fast3dWindow.cpp:196-219`, itself calling `SwapBuffersBegin`/`SDL_GL_SwapWindow`). **`WindowIsRunning()` is what `SDL_QUIT`/window-close ultimately flips false** (via `GfxWindowBackendSDL2::Close()` → `mIsRunning = false` → `Fast3dWindow::IsRunning()` → this C bridge).

**Does anything assume main thread == render thread?** Yes, structurally: SDL window creation (`Fast3dWindow::Init()` → `InitWindowManager()` → `new GfxWindowBackendSDL2()` → `gfx_sdl2.cpp:Init()`, which calls `SDL_CreateWindow`/`SDL_GL_CreateContext`) happens inside this same synchronous call chain originating from `main()`/`SDL_main()` — i.e. on the real thread that `SDL_main` runs on. Since the "graph fiber" is not a separate real OS thread (see above), **window creation, the SDL event pump, and every frame's rendering/swap all happen on the one real thread that the OS handed to `main()`**, which for SDL2's iOS backend (`SDL_UIKitRunApp`) *is* the main thread. This is actually the compatible case for iOS's UIKit main-thread requirement — the risk is only if a build ever changed `Graph_ThreadEntry` to run on an actual spawned thread, which it currently does not.

### C2. iOS main-loop compatibility

**Current structure**: an unbounded C `while (WindowIsRunning()) { RunFrame(); }` loop (`graph.c:519-523`) that never returns to the OS between frames except via its own internal `SDL_PeepEvents` pump — a classic "blocking loop" application model, the same pattern used by every desktop platform this code already ships on.

**SDL2-on-iOS compatibility**: SDL2's iOS support (`SDL_uikitappdelegate.m` in SDL internals) is explicitly designed to accommodate exactly this blocking-loop model without requiring `SDL_main` restructuring: `SDL_UIKitRunApp` wraps the caller's `main()` and, by default, if the app never calls `SDL_iPhoneSetAnimationCallback`, SDL runs the blocking loop under a `UIApplicationMain`-managed context using an internal trick (a run-loop observer / GCD dispatch that lets the blocking `main()` coexist with UIKit's run loop) — this is the same mechanism used by every other SDL2 game on iOS (e.g. any Steam/itch SDL2 port) and does not, by itself, require moving off a blocking loop. **No `SDL_MAIN_HANDLED`/`SDL_main` macro restructuring is needed for the loop shape itself** — this codebase already uses the portable `int main(int argc, char* argv[])` (non-Windows branch, `main.c:59`) that SDL2's `SDL_main.h` on iOS will pick up and redirect via its own `#define main SDL_main`-style plumbing (standard for all SDL2 targets, not iOS-specific code here).

**What *does* need attention for iOS specifically**:
1. **Backgrounding**: the blocking loop has no yield point where it can detect "app about to suspend" and stop touching the GPU — per Apple's rules, apps must stop all GPU/Metal work before `applicationDidEnterBackground` returns or risk being killed for GPU access violations. Since SDL2 delivers `SDL_APP_WILLENTERBACKGROUND`/`SDL_APP_DIDENTERBACKGROUND` as ordinary events into the same queue this loop already pumps (`gfx_sdl2.cpp:666-674`), the fix is additive (new `case` labels in `HandleSingleEvent`, `gfx_sdl2.cpp:619-663`) rather than a structural rewrite — but it does require the loop to actually *pause* rendering (not just acknowledge the event) while backgrounded, e.g. by blocking inside the event-pump call until a resume event arrives, since there's no separate animation-callback path today (`SDL_iPhoneSetAnimationCallback` is not used anywhere in the tree — confirmed via the same lifecycle-symbol grep in B2).
2. **Frame pacing**: `SyncFramerateWithTime()` (`gfx_sdl2.cpp:697-738`) does manual `nanosleep`-based frame pacing against `SDL_GetPerformanceCounter`; this is orthogonal to iOS and should work unchanged, though a `CADisplayLink`-driven approach (which is what `SDL_iPhoneSetAnimationCallback` gives you) is generally considered more power-efficient/App-Review-friendly on iOS than a spin/sleep loop — a nice-to-have optimization, not a blocker.
3. **`main()`/`SDL_main` definition**: `main.c:46-60` only special-cases `_WIN32` (console allocation, UTF8 locale) vs. everything else (`int main(int argc, char* argv[])`, no `SDL_main.h` include, no `#include <SDL.h>` at all in `main.c`). Since SDL2 headers aren't included here, the plain `main` symbol is what's defined; SDL2's `SDL_main.h` macro renaming (`#define main SDL_main`) is normally pulled in transitively by whichever SDL-touching translation unit is linked with `SDL2main` — **worth verifying at iOS-integration time that the executable target actually links `SDL2main`/gets the `SDL_main` redirection**, since `ios.cmake:90` only wires `SDL2::SDL2-static SDL2::SDL2main` into the **ImGui** target, not (visibly, from this file alone) into the actual SoH app executable target — that linkage lives in `soh/soh/CMakeLists.txt`, which currently has **zero iOS-specific lines** (confirmed via grep), i.e. **the SoH app target itself has not yet been wired for iOS build output at all** — this is the single biggest remaining gap, more so than any SDL/audio/threading code issue.

### C3. Lifecycle events — quit / suspend / resume

**Today's quit path** (no backgrounding-awareness at all):
1. `SDL_QUIT` (or `SDL_WINDOWEVENT_CLOSE` on the main window) → `GfxWindowBackendSDL2::Close()` → `mIsRunning = false` (`gfx_sdl2.cpp:292-294,648-654,660-662`).
2. `Graph_ThreadEntry`'s `while (WindowIsRunning())` exits (`graph.c:519-523`), eventually reaching `exit(0)` at `graph.c:516` **or** returning up through `Main()`'s message loop and into `main.c:69`'s `DeinitOTR()` — both paths funnel through `DeinitOTR()` (`OTRGlobals.cpp:1610-1630`) which calls `SaveManager_ThreadPoolWait()`, `OTRAudio_Exit()` (thread join, B3), network/CrowdControl teardown, and finally `OTRGlobals::Instance->context = nullptr` (`:1629`) — dropping the last reference to the `Context` singleton.
3. `Context::~Context()` (`lus-pinned/src/ship/Context.cpp:42-64`) is where the actual **config flush happens**: `GetWindow()->SaveWindowToConfig()` (`:44`) then, after tearing down all subsystems, `GetConfig()->Save()` (`:61`).
4. Several UI "confirm quit"/error-dialog callbacks call `exit(0)` directly (e.g. `OTRGlobals.cpp:514,535,543,555,583,629,700,711`) — since `exit()` (not `_exit`/`quick_exit`) still runs static-storage-duration destructors, the `Context::mContext` static `unique_ptr` (`Context.cpp:32`) destructor still fires and still saves config even on these direct-`exit()` paths. **So today, config save is reliably tied to process exit, by construction, regardless of which of the many `exit(0)` call sites triggers it.**

**Why this breaks on iOS**: iOS apps are **suspended**, not exited, when backgrounded (`applicationDidEnterBackground`) — the process keeps running in a frozen state and can later be silently killed by the OS under memory pressure with **no callback delivered at all** (`applicationWillTerminate` is not guaranteed to run for backgrounded-then-killed apps, only for foreground termination). Since this codebase's *only* save-flush trigger is "the process calls `exit()`" (directly or via the fiber-loop's exit path), **a user who backgrounds the app and it later gets reaped by iOS will lose any config/settings/save-state changes made since the last explicit save**, because no destructor chain ever runs. This is functionally identical to a hard crash from the engine's point of view.

**What suspend/resume would need on iOS** (concrete hooks, given the code as found):
- **On `SDL_APP_WILLENTERBACKGROUND`** (new case in `gfx_sdl2.cpp:619-663`'s switch): synchronously call the same save path `Context::~Context()` uses today — i.e. expose `SaveWindowToConfig()` + `GetConfig()->Save()` as a callable "flush now" entry point (both already exist as methods, just never invoked outside the destructor/individual setters) — and additionally pause the audio device (`SDLAudioPlayer`'s existing `SDL_PauseAudioDevice(mDevice, 1)`, currently only called from `DoClose()`, `SDLAudioPlayer.cpp:15`) so it's not consumed while suspended.
- **Stop GPU work** before returning from that handler — i.e. don't let `RunFrame()`/`SDL_GL_SwapWindow` (`gfx_sdl2.cpp:750`) run again until resume; today's loop has no gate for this at all.
- **On `SDL_APP_DIDENTERFOREGROUND`**: resume audio (`SDL_PauseAudioDevice(mDevice, 0)`), and likely need to recreate/validate the GL/Metal context depending on how aggressively iOS reclaimed GPU resources during suspension (SDL2 generally handles GL context preservation across a normal suspend, but this hasn't been exercised by this codebase at all, so it's untested territory).
- **On `SDL_APP_LOWMEMORY`**: nothing in the resource-loading/caching layer (`ResourceManager`, `ArchiveManager`) currently has any low-memory eviction hook — worth a note for a follow-up investigation, out of scope here.
- **`SDL_APP_TERMINATING`**: would be the last-resort forced-flush point equivalent to today's `exit(0)`-triggered destructor chain, for the case where iOS does grant a final callback before hard-killing.

None of this requires restructuring the blocking loop into a callback/animation-driven model (SDL2 delivers these as ordinary queued events compatible with the existing `SDL_PeepEvents`-based pump) — it requires **adding the missing `case` handling** in `gfx_sdl2.cpp:619-663` and **exposing the config/save-state flush and audio-pause operations as directly callable functions** rather than only reachable via full teardown/destruction.

---

## Summary of concrete file:line action items for iOS

1. `lus-pinned/src/fast/backends/gfx_sdl2.cpp:238-256` — fullscreen toggle wrongly routes iOS through the macOS-native-fullscreen path (`__APPLE__`-gated, not `__IOS__`-excluded); needs an explicit iOS carve-out (likely a no-op, since iOS windows are always "fullscreen").
2. `lus-pinned/src/fast/backends/gfx_sdl2.cpp:619-663` — `HandleSingleEvent` has no cases for any `SDL_APP_*` lifecycle events; needs cases added, wired to a new flush/pause API.
3. `lus-pinned/src/ship/audio/CoreAudioAudioPlayer.cpp:47` (`kAudioUnitSubType_HALOutput`) + `Audio.cpp:24-27,51-53,100-102` — CoreAudio backend is macOS-only under a bare `__APPLE__` guard; either add an iOS `RemoteIO`/`AVAudioSession` variant or exclude iOS from `AudioBackend::COREAUDIO` and let it fall through to `SDLAudioPlayer`. As-is, iOS builds would silently get `NullAudioPlayer` (no sound).
4. `lus-pinned/src/ship/Context.cpp:42-64` — config/save flush lives only in the `Context` destructor; needs to be callable directly from a new background-lifecycle event handler, since destructors won't run when iOS kills a suspended process.
5. `soh/soh/CMakeLists.txt` / `soh/CMakeLists.txt` — **zero iOS-specific lines found anywhere in SoH's own CMake**; the app-executable target itself (as opposed to the LUS engine library it links) has not been wired for iOS output, Info.plist, app icons, or `SDL2main` linkage at all. This is the largest remaining gap — everything else documented here is refinement of engine code that already has a real iOS build path via `lus-pinned/cmake/dependencies/ios.cmake` and `ios-toolchain-populate.cmake`.
