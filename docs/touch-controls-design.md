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
│  [ L ] [ Z ]                               [Start] [ R ]      │
│  (small D-pad)                               ( B ) ( Z )       │
│       ( control stick )                         ( A )          │
│                                            (small C diamond)   │
└──────────────────────────────────────────────────────────────┘
```

- Gameplay controls stay in the lower half of a landscape iPad.
- L/Z and Start/R sit below the menu content line, within reach while holding
  the side edges.
- The compact D-pad sits left of the raised control stick.
- A/B/Z form a separate right-side triangle; the smaller C-button diamond sits
  directly below it.
- The 38-point persistent `•••` menu button sits at the upper-right safe area,
  below Shipwright's menu divider. It remains available when gameplay touch
  controls are disabled.
- Z is intentionally duplicated in the left shoulder row and right face
  cluster; both copies emit the same binding.
- iPhone uses the same relationships at a smaller scale.
- Empty overlay space passes touches through to the game and menus.

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

The on-screen stick is deliberately eight-way in this basic test slice.
Physical controllers retain their normal analog path and remain the reference
for final gameplay feel.

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
- Primary A/B/Z buttons are 66 points at base scale; D-pad buttons are 52,
  C buttons are 46, the menu is 38, and the stick is 150. The smaller
  secondary controls preserve clear gaps between groups.
- A brighter fill while pressed.
- No textures, custom assets, haptics, editor, or resize system.

## Acceptance checks

1. Simulator and unsigned device builds still link.
2. A clean landscape launch displays all 16 discrete buttons plus the stick,
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
9. The physical-controller path and ROM-free package audit are unchanged.

The core grip layout, navigation, gameplay inputs, menu access, and live toggle
were accepted on a 12.9-inch iPad Pro (6th generation). Extended simultaneous
multi-touch stress, iPhone sizing, and physical-controller gameplay remain
hardware acceptance checks.
