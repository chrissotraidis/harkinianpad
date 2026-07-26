# Touch controls: grip-first design

## Goal

Let someone launch and test HarkinianPad without pairing a controller. The
overlay should feel like a compact N64 pad laid across the lower corners of a
landscape iPad, while leaving the center of the game readable.

## Visual reference

The reference supplied on 2026-07-25 establishes four priorities:

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
│                                                              │
│                                                              │
│  [ L ] [ Z ]                               [Start] [ R ]      │
│    ( spaced D-pad )                         ( B ) ( Z )        │
│                                             [menu] ( A )       │
│      ( control stick )                    ( spaced C diamond ) │
└──────────────────────────────────────────────────────────────┘
```

- Every control begins in the lower half of a landscape iPad.
- L/Z and Start/R sit at roughly 43% height, within reach while holding the
  side edges.
- The spaced D-pad and A/B/Z cluster sit at roughly 62% height.
- The menu toggle stays on the outer-right rail between the face and C groups.
- The control stick and spaced C-button diamond share a low thumb line at
  roughly 85% height.
- Z is intentionally duplicated in the left shoulder row and right face
  cluster; both copies emit the same binding.
- iPhone uses the same relationships at a smaller scale.
- Empty overlay space passes touches through to the game and menus.

## Input mapping

The first custom layout reuses HarkinianPad's existing keyboard mappings by
posting SDL key events. This keeps the change inside one iOS bridge and avoids
modifying libultraship's controller model.

| Touch element | Existing binding | N64 action |
|---|---|---|
| Control stick | W, A, S, D | Eight-way control stick |
| D-pad | T, G, F, H | D-pad up/down/left/right |
| A | X | A |
| B | C | B |
| L | E | L |
| Z (left and right) | Z | Z |
| R | R | R |
| Start | Space | Start |
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

## Styling

- Near-black fill at roughly one-third opacity.
- Two-point light border with white labels.
- Circular thumb and face controls; compact pills for shoulders.
- A brighter fill while pressed.
- No textures, custom assets, haptics, editor, or resize system.

## Acceptance checks

1. Simulator and unsigned device builds still link.
2. A clean landscape launch displays all 16 discrete buttons plus the stick,
   with separate, non-overlapping D-pad, stick, face-button, and C-button
   groups in the lower half.
3. Start advances the title screen and A/B navigate file select.
4. The stick and C diamond emit the existing directional inputs.
5. The Controls-menu toggle removes and restores the overlay without restart.
6. The physical-controller path and ROM-free package audit are unchanged.

Physical-iPad grip, simultaneous multi-touch feel, and obscured-content review
remain hardware acceptance checks.
