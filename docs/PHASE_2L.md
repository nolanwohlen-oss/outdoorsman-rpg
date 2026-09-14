# Phase 2L — tackle compatibility and selected bait

World schema 12, inventory version 6, fishing version 3, development v0.13.0.

## Delivered

- A fresh world owns exactly one physical test rod, spoon and hook. Each has a stable item ID, mass, owner and pack/camp location under the existing inventory rules.
- A spoon rig requires the carried test rod and test spoon. A bait rig requires the carried test rod, test hook and a specific carried cut-bait item selected in Layers.
- Rig state stores the exact rod, terminal-tackle and bait IDs. Current saves validate those links against inventory, location and compatibility instead of trusting disconnected strings.
- Casting a bait rig removes exactly 50 g from the selected bait record. Other cut-bait records are unchanged. Depleted bait is removed; casting a spoon consumes no bait.
- Encounter candidates come only from nonzero local populations and use separate bounded placeholder suitability weights for spoon and bait rigs.
- The phone-test bite delay is temporarily reduced from 15 to 2 game minutes. At the 6:1 running clock, that is 20 real seconds. The boundary is exact: setting the hook one millisecond early is rejected.
- Landing or cancellation clears active encounter and item links. Rig identity, selection and timing survive save/load while the encounter is active.

## Test suitability table

| Species | Spoon weight | Bait weight |
| --- | ---: | ---: |
| Mullet | 1 | 2 |
| Atlantic menhaden | 1 | 2 |
| Redfish | 5 | 6 |
| Speckled trout | 6 | 3 |
| Black drum | 1 | 6 |

These integers only weight deterministic test candidates. They are not catch probabilities, balance targets or biological claims.

## Save migration

Schemas 1–11 are validated before conversion. Missing starter equipment is added with new IDs without rewriting existing item IDs or provenance. A schema 11 active lure or bait rig keeps its state and selected bait, then receives compatible rod and terminal-tackle links. Idle legacy records have stale encounter fields cleared. Missing, duplicated, stored or incompatible tackle makes a current active record invalid rather than silently substituting another item.

## Phone acceptance test

1. Install the newest APK as an update and load the previous save. Open Layers and confirm one `test_rod`, one `test_spoon` and one `test_hook`. Existing item IDs and fish history must remain.
2. Retain a fish, return to camp, and use **Prepare bait**. In Layers, leave that exact `cut_bait` item selected, travel to a water zone, then use Clock → **Prepare bait rig with selected item**. The status should say `rigged` and `bait`.
3. Cast once. Return to Layers and confirm that selected bait lost exactly 50 g. A different cut-bait item, if present, must not change.
4. Tap **Run clock** for about 20 real seconds, then **Set hook**. An immediate hook attempt should say no bite; the attempt after two game minutes should work.
5. Cancel or finish the encounter. Select a ration, fish product or other non-bait item and try preparing a bait rig; it must be rejected without consuming anything.
6. Prepare a spoon rig and cast without bait. Then cancel, return to camp, store the spoon, travel back to water and try again. It must reject the rig until the same spoon is returned to the pack.
7. Save and load while a rig is prepared and again while it is cast. Mode, target, bite time and valid equipment links must survive; loading remains paused and adds no offline time.

Report the footer build number, exact step, expected and actual result, and a screenshot for any failure.

## Deliberate limits and next gate

This remains systems-lab scaffolding. The rod, spoon and hook have no reel, line, leader, hook size, knots, durability, loss or damage. The two fixed compatible recipes and suitability table are placeholders, not the final equipment or encounter model. Bite timing is intentionally shortened for testing and will be tuned later. Fish size, strike causes, fight state, tension, player technique, equipment failure and escape reasons are not yet simulated.

The next proposed gate is fight and landing causality: explicit timed decisions, fish exertion and traceable success/failure reasons connected to the same persistent encounter and equipment records.
