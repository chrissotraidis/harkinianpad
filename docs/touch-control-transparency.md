# Touch-control transparency feasibility

## Verdict

Feasible with a small, low-risk implementation. HarkinianPad already owns the
UIKit touch overlay, the native A/B/C artwork bridge, and persisted Settings
widgets, so opacity can change without changing control frames, hit testing,
bindings, or saved layouts.

## Implementation

- **Touch Control Transparency** is default-off, preserving the accepted
  appearance on existing and clean installations.
- Enabling it reveals **Touch Control Opacity**, a persisted 25%–100% slider
  with a 50% default.
- UIKit controls and the permanent menu button use the selected opacity.
- Native gameplay A/B/C artwork and its labels, icons, and ammo counts use the
  same opacity. The regular HUD is unchanged when native touch artwork is not
  active.
- The layout editor temporarily shows controls at full opacity so selection,
  hiding, and resizing remain clear.
- Opacity never changes view visibility, frames, gesture recognizers, or input
  handling.

## Validation gate

Before release, verify default-off parity, both slider extremes, persistence
after relaunch, unchanged hit targets, the full-opacity layout editor, native
A/B/C artwork in gameplay, and both modern and legacy layouts on Simulator and
physical iPad hardware.
