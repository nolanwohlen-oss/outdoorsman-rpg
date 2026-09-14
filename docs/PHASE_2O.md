# Phase 2O — tackle condition and recovery

Development v0.16.0. World schema remains 14 because Phase 2O activates the already-versioned item `condition` field rather than changing record shape. Existing Phase 2N line/reel records use `-1` as a legacy pristine sentinel; the first 2O tackle action materializes that value as 1000/1000.

## Delivered

- Linked test line and reel now have persistent 0–1000 condition.
- Every fish-fight choice applies deterministic line and reel wear from tension, action and fight load.
- Overload explicitly breaks the linked line to 0/1000. A line or reel that reaches zero loses the fish and cannot be used to prepare another rig.
- Tackle wear is resolved inside the same candidate-world transaction as the fight action. Validation failure leaves time, fish state and equipment unchanged.
- Camp service preserves item identity and restores a bounded amount of condition: line +300 in 15 game minutes; reel +250 in 20 game minutes.
- Camp replacement takes 10 game minutes, removes the selected line/reel identity and creates a new full-condition item ID. Replacement currently uses a free systems-lab spare; price, vendors and consumable replacement stock are deferred to the economy/item-content passes.
- Service and replacement reject active fishing and scheduled-action interruption without partial mutation.
- Existing Phase 2N saves remain loadable; the legacy `-1` tackle sentinel is not silently advanced while the game is closed.

## Phone gate

1. Install the newest APK as an update and load the existing world. Footer must show `v0.16.0`.
2. Select the test line and reel in Layers. A Phase 2N save may initially show condition unknown; prepare either fishing rig and confirm both materialize as 1000/1000.
3. Hook a fish and make at least one correct fight choice. Re-open Layers and confirm both linked line and reel are below 1000 and retain those exact values after save/reload.
4. Finish/cancel the encounter, travel to elevated camp, select the line and use **Service selected line/reel**. Confirm 15 game minutes pass, the same line item ID remains, and condition rises by up to 300.
5. Select the reel and use **Replace selected line/reel**. Confirm 10 game minutes pass, the old reel ID disappears, a new reel ID appears at 1000/1000, and save/reload preserves the new identity.
6. Wear or force a linked item to zero during testing and confirm a new rig is rejected until that item is serviced or replaced.

## Deliberate limits

Wear values are deterministic test coefficients, not final fishing-physics tuning. Rod, hook/spoon, knots, drag settings, line type/strength, repair materials, vendor cost and economy are not modeled here. Replacement is intentionally a no-cost test fixture so identity replacement and recovery can be proven before economy content exists.
