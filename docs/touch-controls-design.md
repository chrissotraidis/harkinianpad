# Touch controls: grip-first design

## Goal

Let someone launch and test HarkinianPad without pairing a controller. The
overlay should feel like a compact N64 pad laid across the lower corners of a
landscape iPad, while leaving the center of the game readable.

## Visual reference

The reference supplied on 2026-07-25 establishes five priorities:

1. The control stick sits low under the left thumb.
2. The D-pad and control stick remain separate left-side groups.
3. A, B, and the C buttons form distinct groups under the right thumb.
4. L, Z, R, Start, and the menu toggle stay on the lower side rails instead
   of covering the center or forcing an iPad user to shift their grip upward.
5. Dark translucent controls use thin light outlines and short labels.

This is a layout reference, not a request to copy its game frame, icons, or
ornament.

## Layout

```text
┌──────────────────────────────────────────────────────────────┐
│                                                    [•••]     │
│                                                              │
│  (small D-pad)                            [Start] [ R ]        │
│                                                   [ L ]        │
│                                              ( B ) ( Z )       │
│       ( control stick )                         ( A )          │
│                                            (small C diamond)   │
└──────────────────────────────────────────────────────────────┘
```

- Gameplay controls stay in the lower half of a landscape iPad.
- Start/R sit below the menu content line. L uses the same pill size directly
  below R; the redundant left-side Z target is removed.
- The compact D-pad sits left of the raised control stick. On iPhone, the
  D-pad and C-button rows sit slightly above the face cluster so adjacent
  controls do not intersect.
- A/B/Z form a separate right-side triangle. The smaller C-button diamond sits
  below it on iPad and above it on iPhone so the face buttons occupy the
  phone's natural lower thumb zone.
- The persistent `•••` menu button sits at the upper-right safe area on iPad
  and in a dedicated top-center slot during iPhone gameplay. While the
  Shipwright menu is open on iPhone, it moves to bottom center so it does not
  cover the Settings, Enhancements, Randomizer, or Dev Tools tabs. It remains
  available when gameplay touch controls are disabled.
- Z remains in the right face cluster where it can be held with the movement
  stick.
- iPhone uses a dedicated compact grip layout instead of shrinking the iPad
  geometry proportionally.
- Empty overlay space passes touches through to menus, but synthetic
  touch-as-mouse clicks are not forwarded to gameplay button mappings.

## Input mapping

The touch overlay reuses HarkinianPad's keyboard mappings by posting SDL key
events. Two small iOS-only defaults make external testing less surprising:
Return also maps to Start, while primary, secondary, and middle mouse clicks
map to A, B, and Z.

| Touch element | Existing binding | N64 action |
|---|---|---|
| Control stick | W, A, S, D | Eight-way control stick |
| D-pad | T, G, F, H | D-pad up/down/left/right |
| A | X | A |
| B | C | B |
| L | E | L |
| Z (left and right) | Z | Z |
| R | R | R |
| Start | Space or Return | Start |
| C up/down/left/right | Arrow keys | C buttons |
| Menu | Escape | Open/close HarkinianPad menu |

The on-screen stick is deliberately eight-way in this basic test slice. It
uses separate engage/release thresholds to prevent direction chatter, keeps
smaller deflections cardinal for menu precision, and allows diagonals in the
outer ring. Physical controllers retain their normal analog path and remain
the reference for final gameplay feel.

## Toggle behavior

- Add **Touch Controls** under **Settings → Controls** on iOS.
- Default it to on so a clean install is immediately testable.
- Persist it with the existing CVar configuration.
- Enabling installs the overlay on the active SDL window.
- Disabling removes it immediately and releases every held input.
- Opening the Shipwright menu temporarily removes the gameplay overlay and
  releases held input; closing the menu restores it only when the persisted
  Touch Controls setting remains enabled.
- The independent `•••` button stays installed in either state so disabling
  gameplay controls never strands the user outside Settings.

## Styling

- Near-black fill at roughly one-third opacity.
- Two-point light border with white labels.
- Circular thumb and face controls; compact pills for shoulders.
- N64-inspired hierarchy: blue A, green B, red Start, and amber C buttons.
- Primary A/B/Z buttons are 66 points at the iPad base scale; D-pad buttons
  are 52, C buttons are 46, the menu is 38, and the stick is 150. The iPhone
  layout uses 52-point face buttons, 44-point D-pad buttons and shoulders,
  40-point C buttons, a 44-point menu button, and a 116-point stick.
- A brighter fill while pressed.
- No textures, custom assets, haptics, editor, or resize system.

## Native HUD touch controls

The native-HUD prototype passed on physical iPhone and iPad and is now part of
the default customizable controller. Shipwright supports separate positions
for the native A, B, and four C-button graphics.

The smallest reversible prototype should:

- keep the current UIKit input path and layouts as the fallback;
- render native A/B/C graphics over transparent UIKit hit targets during
  gameplay at the same live centers and visible sizes as the UIKit artwork;
- restore the visible UIKit buttons whenever the gameplay HUD is unavailable,
  including title, file-select, and pause states;
- preserve the established behavior of hiding the complete gameplay overlay
  while the Shipwright menu is open;
- reuse the automatically selected V1 iPhone and iPad layouts without a second
  experimental position preset; and
- keep C-up discoverable for normal input while preserving Navi's conditional
  prompt behavior.

The implementation history is tracked in
[`native-hud-touch-experiment.md`](native-hud-touch-experiment.md). It is
paired with transparent UIKit hit targets and the accepted device-specific
customizable layouts. The prior fixed UIKit controller remains available
through **Legacy Fixed Touch Controls**.

Simulator proof is necessary for layout work, but final acceptance requires
physical gameplay on both device classes.

## Acceptance checks

1. Simulator and unsigned device builds still link.
2. A clean landscape launch displays all 15 discrete buttons plus the stick,
   with separate, non-overlapping D-pad, stick, face-button, and C-button
   groups in the lower half.
3. Start advances the title screen and A/B navigate file select.
4. The stick and C diamond emit the existing directional inputs.
5. Opening the menu hides the complete gameplay overlay; closing it restores
   the overlay only when Touch Controls remains enabled.
6. The Controls-menu toggle removes and restores the overlay without restart.
7. A clean/default keyboard configuration accepts Space and Return for Start.
8. A clean/default mouse configuration maps primary/secondary/middle click to
   A/B/Z.
9. Empty-screen taps do not trigger A, while menu touch and physical mouse
   input remain available.
10. The physical-controller path and ROM-free package audit are unchanged.

The core grip layout, navigation, gameplay inputs, menu access, and live toggle
were accepted on a 12.9-inch iPad Pro (6th generation). Extended simultaneous
multi-touch stress, iPhone sizing, and physical-controller gameplay remain
hardware acceptance checks.
