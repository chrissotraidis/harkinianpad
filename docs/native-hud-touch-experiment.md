# Native HUD touch implementation history

## Status

**Promoted into the default customizable touch controller on 2026-07-29.**

The previous fixed UIKit controller remains available through **Settings >
Controls > Legacy Fixed Touch Controls**. **Touch Controls** must remain
enabled for either controller.

This document preserves the experiment and physical-test history that led to
promotion. Do not infer acceptance of a new build from an older checkpoint.

## Product contract

- Default on as part of the customizable controller.
- Enabling Legacy Fixed Touch Controls restores the previous UIKit controller
  immediately without a restart.
- Gameplay uses the accepted customized touch geometry independently on iPhone
  and iPad.
- The clear UIKit hit targets remain fully opaque and interactive while
  posting the existing SDL keyboard bindings. Only their artwork is hidden.
- Only A, B, C-up, C-down, C-left, and C-right change appearance.
- The stick, D-pad, L, Z, Start, R, minimap, and `•••` remain in
  their V1 locations.
- UIKit publishes the live A/B/C frame widths as well as their centers. Native
  artwork scales to those widths independently, preserving the different V1
  face-button and C-button diameters.
- The visible V1 face buttons return when the gameplay HUD is unavailable,
  including title, file select, name entry, and pause.
- Opening the Shipwright menu keeps the established behavior: the complete
  gameplay overlay is removed until the menu closes.
- C-up remains touchable, while its native Navi graphic keeps the game's
  conditional visibility.
- The prototype does not write or replace the user's Shipwright HUD cosmetics
  positions.

## Phase 1 implementation

The first slice deliberately tests alignment and interaction before scaling:

1. UIKit publishes normalized centers and widths for the accepted A/B/C
   frames.
2. The Shipwright HUD converts those centers into its 240-high virtual
   coordinate space using the live aspect ratio.
3. Native A/B/C backgrounds, item icons, ammo counts, empty C arrows, and
   action labels are centered on those locations during eligible gameplay.
4. The matching UIKit artwork becomes clear without lowering the controls'
   layer opacity, disabling hit testing, or changing their SDL mappings.
5. Leaving eligible gameplay or disabling the setting restores UIKit artwork.

The implementation is isolated in
`patches/shipwright-ios-native-hud-touch-experiment.patch`, applied after the
stable `shipwright-ios-touch-controls.patch`.

## Known limits

- C-up is visually absent unless the game is displaying Navi's C-up prompt.
- The native artwork itself adds no new input path; the surrounding
  customizable controller provides the layout editor and Z-latch haptic.
- General Shipwright HUD scaling remains incomplete; this experiment does not
  enable or modify that unfinished editor.
- Simulator results establish layout behavior only. Physical iPhone and iPad
  thumb reach and general playability are accepted for this opt-in release;
  exhaustive simultaneous-touch and transition coverage remains open.

## Test matrix

| Check | iPhone Simulator | iPad Simulator | Physical iPhone | Physical iPad |
|---|---|---|---|---|
| Default-off V1 matches accepted layout | Pass | Pass | Pass | Pass |
| Toggle on/off works without restart | Pass | Partial: persisted opt-in exercised; live toggle pending | Pass | Pending |
| Native A/B/C align with V1 touch centers and sizes | Pass | Pass | Pass | Pass |
| Title/file/name entry show V1 controls | Partial: title passed; file/name pending | Partial: debug warp passed; title/file/name pending | Pending | Pending |
| Pause and Shipwright menu restore/hide correctly | Partial: menu passed; pause pending | Partial: menu opened correctly; pause pending | Pending | Pending |
| A/B/C inputs and multi-touch combinations work | Partial: A/B passed after clear-hit-target revision; C and multi-touch pending | Partial: A/B passed after clear-hit-target revision; instrumented C-down passed; remaining C and multi-touch pending | Partial: gameplay controls exercised; exhaustive multi-touch pending | Partial: gameplay controls exercised; exhaustive multi-touch pending |
| Item icons, ammo, labels, Navi, and empty arrows align | Partial: icons, ammo, and Navi observed | Partial: icons, ammo, and Navi observed | Partial: representative gameplay accepted; full state matrix pending | Partial: representative gameplay accepted; full state matrix pending |
| No new minimap or menu obstruction | Pass | Pass | Pass | Pass |
| Physical controller path remains unchanged | Pending | Pending | Pending | Pending |

## Checkpoints

| Date | Revision/build | Evidence | Result |
|---|---|---|---|
| 2026-07-28 | `codex/native-hud-touch-experiment` Phase 1 source checkpoint | Default-off toggle, V1 fallback, native-position bridge, and canonical patch added | Ready for build |
| 2026-07-28 | Release Simulator build from Phase 1 branch | Full `scripts/build-ios.sh --simulator` compile/link, repository safety check, and reverse patch check | Pass |
| 2026-07-28 | Same build on iPhone 17 Pro Simulator, iOS 26.5 | Compared default V1 and experimental gameplay; exercised menu toggle off and transparent A/B targets | Simulator checkpoint passed with follow-ups below |
| 2026-07-28 | Same build on iPad Pro 13-inch (M5) Simulator, iOS 26.5 | Compared default V1 and opt-in gameplay in landscape; exercised transparent A/B targets and opened Shipwright menu | Simulator checkpoint passed with follow-ups below |
| 2026-07-28 | iPhone compact-layout revision on iPhone 17 Pro Simulator, iOS 26.5 | Raised stick, expanded C spacing, compact A/B/Z triangle, and transient minimap/menu offsets; full Simulator rebuild and final incremental rebuild passed | Visual implementation verified; physical and user acceptance pending |
| 2026-07-28 | iPad thumb-lane and native-scale revision on iPad Pro 13-inch (M5) Simulator, iOS 26.5 | Inset and lifted A/B/Z, lifted C diamond, top-right minimap/menu, fixed 72% native artwork scale, larger transparent targets, and successful incremental compile/link | Simulator implementation verified; physical and user acceptance pending |
| 2026-07-28 | iPad A/B alignment and input revision on iPad Pro 13-inch (M5) Simulator, iOS 26.5 | Corrected Shipwright A's fixed 23-point renderer offset, replaced opacity-based hiding with fully active clear UIKit targets, rebuilt, and clicked the visible B center in gameplay | A/B/Z now form the intended triangle and B produced the sword action; physical and user acceptance pending |
| 2026-07-28 | Same A/B alignment and input revision on iPhone 17 Pro Simulator, iOS 26.5 | Reinstalled the same build, entered gameplay, checked the compact A/B/Z cluster, and clicked the visible B center | iPhone alignment remained intact and B produced the sword action; physical and user acceptance pending |
| 2026-07-28 | iPad directional-triad revision on iPad Pro 13-inch (M5) Simulator, iOS 26.5 | Re-shaped B/A/Z as left, down-right, and upper points; lowered C and Start/R; moved C slightly left to keep conditional C-up clear of Start; rebuilt and reinstalled twice while checking visible and touch-target spacing | Final Simulator geometry has separated hit regions and matches the requested directional relationship; physical and user acceptance pending |
| 2026-07-29 | V1 geometry-parity revision on iPhone 17 Pro Simulator, iOS 26.5 | Removed experimental layout, minimap, and menu offsets; native A/B/C consume the live V1 frame centers and widths; toggled between V1 and native artwork in the same gameplay scene | Simulator build and visual center/diameter comparison passed; physical iPhone retest pending |
| 2026-07-29 | Same V1 geometry-parity revision on physical iPhone 14 | Exact device app passed strict signing verification, installed in place without touching the iPad, launched, and remained live as process 1465 | Deployment passed; physical layout and touch acceptance pending |
| 2026-07-29 | Shared shoulder-layout revision on iPhone 17 Pro and iPad Pro 11-inch (M5) Simulators, iOS 26.5 | Removed the redundant left Z target; moved the same-size L pill below R; shifted only the compact iPhone C diamond left enough to keep conditional C-up/Navi clear; raised the tablet Start/R/L stack to preserve a scaled 12-point gap above right Z | Simulator build and visual frame checks passed; physical iPhone touch acceptance pending |
| 2026-07-29 | Same shared shoulder-layout revision on physical iPhone 14 | Exact device app passed strict signing verification, installed in place without touching the physical iPad, launched, and remained live as process 1484; user compared V1 and experimental modes in gameplay | Physical iPhone layout accepted in both modes |
| 2026-07-29 | Same iPhone-accepted revision on physical iPad Pro 12.9-inch (6th generation) | Exact signed app installed in place, launched, and remained live as process 2224 | Deployment passed; physical iPad layout and touch acceptance pending |
| 2026-07-29 | iPad 20%-size and Navi refinement on iPad Pro 13-inch (M5) Simulator, iOS 26.5 | Increased tablet A/B/Z and C hit frames by exactly 20%; shifted only A/B/Z farther left; stacked C directly below; lowered Start/R/L without overlap; moved the menu to the top-right safe corner; corrected C-up's 16-point native scaling basis and lowered its frame 8 scaled points; rebuilt, installed, and inspected in landscape gameplay | Build and structural layout checks passed; user visual acceptance and physical iPad testing pending |
| 2026-07-29 | Same iPad 20%-size and Navi refinement on physical iPad Pro 12.9-inch (6th generation) | Exact arm64 app passed strict signing verification, installed in place on device `95937B69-2038-56A0-8069-0EB0484BC2F9`, launched, and remained live as process 2549 | Deployment passed with existing app data preserved; physical layout and touch acceptance pending |
| 2026-07-29 | Tablet lower-cluster lift on physical iPad Pro 12.9-inch (6th generation) | Preserved Navi/C-up and all other accepted tablet controls; moved C-left, C-right, and C-down upward together by 14 scaled points and lifted the stick 12 scaled points; representative iPad geometry remained separated and in bounds; exact signed app installed in place, launched, and remained live as process 2567 | Deployment passed with existing app data preserved; physical layout and touch acceptance pending |
| 2026-07-29 | Tablet micro-adjustment on physical iPad Pro 12.9-inch (6th generation) | Preserved Navi/C-up and all other controls; moved C-left, C-right, and C-down another 6 scaled points upward together; moved the stick another 5 scaled points up and 6 scaled points right; representative iPad geometry remained separated and in bounds; exact signed app installed in place, launched, and remained live as process 2583 | Physical iPad layout accepted for opt-in experimental release; default-promotion gates remain open |
| 2026-07-29 | Repository release candidate | Removed an unused always-disabled minimap-offset path; regenerated the maintained patch from the pinned Shipwright base; verified clean apply, exact source parity, reverse apply, idempotent patching, shell syntax, repository safety, and prohibited-asset/secret absence; rebuilt and linked the arm64 Release Simulator app | Ready for opt-in, default-off repository inclusion |

## Feedback log

Add one row per meaningful test session.

| Date | Build | Device and OS | Mode/screen | Observation | Follow-up |
|---|---|---|---|---|---|
| 2026-07-28 | Phase 1 | iPhone 17 Pro Simulator, iOS 26.5 | Title and gameplay, V1 | Default-off build retained the accepted UIKit layout | Recheck on a physical iPhone |
| 2026-07-28 | Phase 1 | iPhone 17 Pro Simulator, iOS 26.5 | Gameplay, experimental | Native A/B/C content moved to the accepted touch centers; the transparent A and B targets still posted gameplay input | Test every C direction and simultaneous stick/button input physically |
| 2026-07-28 | Phase 1 | iPhone 17 Pro Simulator, iOS 26.5 | Shipwright menu and gameplay | Experimental checkbox was visible under Controls; disabling it live restored the complete V1 face-button artwork | Re-enable live and test pause/file/name transitions |
| 2026-07-28 | Phase 1 | iPad Pro 13-inch (M5) Simulator, iOS 26.5 | Debug warp and gameplay, V1 | Default-off build retained the accepted iPad layout in landscape | Recheck on a physical iPad |
| 2026-07-28 | Phase 1 | iPad Pro 13-inch (M5) Simulator, iOS 26.5 | Gameplay, experimental | Native icons, ammo, A/B labels, and the Navi prompt followed the iPad touch centers; transparent A and B targets still posted input | Live menu retoggle, all C targets, pause, and multi-touch remain open |
| 2026-07-28 | Phase 1 | Both Simulators | Gameplay, experimental | Native artwork is intentionally smaller than V1 and still occupies the accepted lower-right control region near the minimap | Get visual approval before implementing a separate native-scaling phase |
| 2026-07-28 | iPhone compact-layout revision | iPhone 17 Pro Simulator, iOS 26.5 | Gameplay, experimental | Stick cleared the rupee count; C spacing opened up; A/B/Z formed a cleaner cluster; minimap and menu moved up/right. A compass-sign correction kept the player marker attached to the shifted map. | Get user visual approval, then repeat on a physical iPhone; V1 and iPad remain unchanged |
| 2026-07-28 | iPad thumb-lane revision | iPad Pro 13-inch (M5) Simulator, iOS 26.5 | Gameplay, experimental | First draft put A/B too near the edge and let Z crowd C-down. Final draft inset and lifted A/B/Z, lifted and spread C, kept the map/menu upper-right, and reduced native A/B/C artwork to 72% without shrinking the larger touch targets. | Get user visual approval, then test thumb reach and simultaneous inputs on a physical iPad |
| 2026-07-28 | iPad thumb-lane revision | iPad Pro 13-inch (M5) Simulator, iOS 26.5 | C-down input, experimental | The previously uncertain C-down target emitted SDL scancode 81. Temporary diagnostic logging was removed; the later clear-hit-target revision also removed the opacity threshold entirely. | Test the remaining five native targets and multi-touch physically |
| 2026-07-28 | iPad A/B alignment and input revision | iPad Pro 13-inch (M5) Simulator, iOS 26.5 | Gameplay, experimental | A had been drawn down/right because its centered-quad renderer uses a fixed 23-point legacy offset unlike B's texture path. Correcting that offset aligned the visible A/B pair beneath Z. UIKit artwork is now hidden with clear colors while the controls stay fully opaque and interactive. Clicking visible B changed Link into the sword-action state. | Get user visual approval, then repeat A/B/C and simultaneous-input checks on a physical iPad |
| 2026-07-28 | A/B alignment and input revision | iPhone 17 Pro Simulator, iOS 26.5 | Gameplay, experimental | The same build preserved the compact phone layout after the shared A renderer correction. Clicking visible B raised Link's sword. | Repeat on a physical iPhone and test the remaining C and simultaneous inputs |
| 2026-07-28 | iPad directional-triad revision | iPad Pro 13-inch (M5) Simulator, iOS 26.5 | Gameplay, experimental | The horizontal A/B pair did not match the intended controller relationship. B is now the left point, A is down/right, and Z closes the triangle above. C and Start/R moved down; C also moved slightly left so its conditional upper target does not compete with Start. B/Z spacing was opened enough to keep their full touch frames separate. | Get user visual approval, then repeat thumb-reach and simultaneous-input checks on the physical iPad |
| 2026-07-29 | Pre-parity physical build | iPhone 14 | Gameplay, V1 versus experimental | Opting in worked, but the experimental A/B/Z and C geometry visibly diverged from the accepted V1 layout. | Remove the second geometry and make native artwork use V1 centers and visible sizes pixel-for-pixel |
| 2026-07-29 | V1 geometry-parity revision | iPhone 17 Pro Simulator, iOS 26.5 | Same gameplay scene, V1 versus experimental | A/B/C native centers and diameters matched the V1 buttons; Z and all non-native controls remained stationary across the toggle. | Install the same source revision on the physical iPhone 14 for user acceptance |
| 2026-07-29 | Post-parity physical build | iPhone 14 | Gameplay, experimental | Native layout parity looked good; the redundant left Z consumed space and L remained isolated on the left despite being a low-frequency map control. | Remove left Z, place L below R in both device layouts, and preserve clearance from conditional C-up/Navi |
| 2026-07-29 | Shared shoulder-layout revision | iPhone 17 Pro and iPad Pro 11-inch (M5) Simulators, iOS 26.5 | Both layouts expose one right-side Z target and place L below R. The phone C diamond remains clear of L. The first tablet render exposed L/Z overlap, so the Start/R/L stack was raised and re-rendered with separated hit frames before deployment. | Install the exact source revision on the physical iPhone 14 and verify thumb reach plus Navi/C-up clearance |
| 2026-07-29 | Shared shoulder-layout revision | iPhone 14 | Gameplay, V1 versus experimental | User confirmed both modes return correctly, share the intended placement, reduce occupied space, and look and work great on iPhone. | Preserve the accepted iPhone geometry while reviewing the same revision on the physical iPad |
| 2026-07-29 | Shared shoulder-layout revision | iPad Pro 12.9-inch (6th generation) | Installed and launched for physical review | The same iPhone-accepted build is live with existing app data preserved. | User to compare V1 and experimental layout, thumb reach, button input, and Navi/C-up clearance |
| 2026-07-29 | iPad 20%-size and Navi refinement | iPad Pro 13-inch (M5) Simulator, iOS 26.5 | Gameplay, experimental | The first tablet pass made A/B/Z and the C diamond easier to reach, but A/B/Z still needed a small left shift and conditional C-up/Navi remained undersized and high. The follow-up preserves the accepted phone branch, moves only tablet A/B/Z 10 scaled points left, makes C-up consume its full enlarged target width, and lowers C-up 8 scaled points. | Get user visual approval in the open Simulator, then install this exact revision on the physical iPad |
| 2026-07-29 | iPad 20%-size and Navi refinement | iPad Pro 12.9-inch (6th generation) | Installed and launched for physical review | The Simulator-approved source revision is live after an in-place update; the iPhone was not targeted. | User to test both V1 and experimental modes, all A/B/Z/C inputs, thumb reach, and conditional Navi/C-up size and position |
| 2026-07-29 | iPad 20%-size and Navi refinement | iPad Pro 12.9-inch (6th generation) | Gameplay, experimental | Physical thumb testing found the layout broadly good. Navi/C-up should remain fixed, while the other three C buttons need to move upward as one formation; the analog stick also needs a small upward adjustment. | Lift only C-left, C-right, C-down, and the tablet stick; rebuild and install in place for another physical pass |
| 2026-07-29 | Tablet lower-cluster lift | iPad Pro 12.9-inch (6th generation) | Gameplay, experimental | The first lower-cluster lift improved the layout; physical thumb testing requested one final small upward nudge for the three non-Navi C buttons and a tiny up-and-right stick adjustment. | Preserve Navi and every other control; apply only the requested micro-adjustment and reinstall in place |
| 2026-07-29 | Tablet micro-adjustment | iPad Pro 12.9-inch (6th generation) | Gameplay, experimental | User accepted the final physical iPad layout. Together with the accepted physical iPhone layout, the experiment is ready for opt-in, default-off repository inclusion. | Keep the experiment default-off; complete the transition, multi-touch, and controller matrices before considering default promotion |

## Promotion decision

The user accepted the native HUD geometry and touch behavior on both physical
device classes and requested promotion on 2026-07-29. The legacy fixed UIKit
controller remains available for the validation cycle. Each promoted build
must still be installed and reviewed on both devices before publication.
