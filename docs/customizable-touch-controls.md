# Customizable touch controls

HarkinianPad uses customizable touch controls by default. The built-in phone
and tablet layouts are the exact normalized layouts accepted on the physical
iPhone and iPad on 2026-07-29. **Legacy Fixed Touch Controls** remains
available under **Settings > Controls** as the non-customizable fallback.

**Customize Touch Layout** closes Settings and opens a native editor over the
live controls:

- tap a control to select it;
- drag the selected control to move it;
- use **Size** to scale it from 70% to 150%;
- use **Hide/Show** for buttons that are not needed;
- use **Reset** to restore the accepted defaults for the current device class;
- use **Done** to save and return to gameplay.

The controller also includes a shared iPhone/iPad Z latch. Hold Z for 0.5 seconds
to lock it down. A haptic pulse confirms the lock and Z remains filled blue;
tap Z again to release it. Opening the menu, entering the layout editor,
enabling the legacy controls, or backgrounding the app releases the latch so
input cannot remain stuck across a state change.

The control stick cannot be hidden, and the permanent `•••` menu control is
not editable. Starting the editor releases held input and temporarily disables
the controls' normal gameplay handlers.

**Touch Control Transparency** under **Settings > Controls** reveals a
25%–100% **Touch Control Opacity** slider. The option is off by default, and
the layout editor temporarily restores full opacity without changing the saved
preference or any touch target.

## Persistence and layout rules

Phone and tablet layouts are stored separately in `NSUserDefaults`:

```text
HarkinianPad.TouchLayout.phone-v1
HarkinianPad.TouchLayout.tablet-v1
```

Each profile contains property-list-safe normalized centers, scalar sizes, and
hidden control IDs. Saved controls are rebuilt from the current accepted
defaults, then clamped inside the current safe area. Reset removes the current
profile's overrides rather than replacing the defaults with a copied layout.

The native-HUD renderer consumes the final customized A/B/C centers and sizes.
Hiding one of those controls also suppresses its native HUD artwork. Native
artwork is disabled while editing so each UIKit control and its hit target can
be selected directly.

## Validation status

Promotion evidence on 2026-07-29:

- the arm64 iOS Simulator app compiled and linked;
- Settings opened the editor on iPhone 17 Pro and iPad Pro 13-inch (M5)
  Simulators;
- selection, 70–150% resizing, Hide/Show, protected-stick behavior, Reset,
  Done, and separate `phone-v1`/`tablet-v1` storage were exercised;
- the permanent menu disappeared only while editing and returned after Done;
- patch reverse-application and replay reproduced the tested source.

- the shared Z-latch revision compiled and linked for arm64 Simulator and
  device targets, passed strict device-signature verification, and was
  accepted on physical hardware;
- the accepted saved `phone-v1` and `tablet-v1` profiles were captured before
  promotion and embedded as the clean-install and Reset defaults.

The current promoted build still requires a final physical iPhone/iPad
regression pass before publication. Simulator proof does not replace that
hardware acceptance.
