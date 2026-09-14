# Phase 2P — rig causality

Development v0.17.0. Phase 2P deepens the existing fishing fixture without changing the serialized world-record shape.

## Delivered

- Rod, reel, line, spoon and hook all use the existing persistent 0–1000 item condition field.
- Rigging materializes legacy `-1` equipment condition as pristine 1000/1000, preserving older saves.
- Every fight choice wears all four linked rig components: rod, reel, line and terminal tackle.
- Line condition now sets a deterministic load limit. Worn line can break under tension that a pristine line survives.
- Rod condition reduces the effective safe line-load envelope, making rod degradation mechanically causal.
- Terminal-tackle condition sets a deterministic load limit. A badly worn spoon/hook can fail independently of the line.
- Fight actions now take an explicit loose, balanced or tight drag input. Loose drag lowers tension but gives the fish distance and stamina; tight drag raises tension and gains control at greater break risk.
- The selected drag choice and all four condition values are written into the fight log. No hidden random durability roll is used.
- Broken rod, reel, line or terminal tackle blocks preparation of a new rig until the item is serviced or replaced at camp.
- Camp service/replacement now supports every tracked rig component while preserving the Phase 2O transactional guarantees.

## Android phone gate

1. Install the newest APK as an update and confirm the footer reports `v0.17.0` and the header reports `PHASE 2P`.
2. Prepare a spoon or bait rig. In Layers, confirm rod, reel, line and terminal tackle all show condition.
3. Hook a fish. Set **Loose drag**, make one fight choice, and note tension/distance. Reload the same pre-choice save if desired, choose **Tight drag**, and confirm the result visibly changes.
4. Make several normal fight choices and confirm all four linked rig items lose condition and preserve the exact values through save/reload.
5. Continue using worn line or terminal tackle until a failure occurs, or use the test fixtures to force low condition. Confirm the loss message names tackle failure/overload and a broken component reaches 0/1000.
6. Confirm a new rig is rejected while a required component is at zero.
7. Travel to elevated camp, service the damaged rod/terminal item, confirm the same item ID remains and condition rises, then replace one tracked component and confirm its identity changes.

## Deliberate limits

The load limits, wear rates and drag offsets are deterministic test coefficients, not final fishing-physics tuning. Line material/diameter, knots, rod power/action, reel drag hardware, hook gauge, lure weight, spool fill, leader construction and player skill are deferred. Drag is an explicit fight input rather than a continuously adjustable physical control in this systems-lab slice.
