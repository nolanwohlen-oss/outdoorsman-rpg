# Phase 2J — explicit fish uses

World schema 10, inventory version 4, development v0.11.0.

## Player choices

Select an item in Layers, then choose its use. Unused catches stay whole fish.

| Action | Requirement | Game time | Result |
| --- | --- | --- | --- |
| Clean | Whole or legacy fish at camp | 10 min | Cleaned fish, 60% mass retained (floor, minimum 1 g); removed processing waste logged |
| Prepare bait | Whole, legacy or cleaned fish at camp | 5 min | Cut bait, same mass, no nutrition |
| Cook | Cleaned fish at camp plus one firewood unit | 15 min | Cooked fish, same fish mass; 100 g fuel consumed |
| Eat | Accessible cooked fish | 5 min | Up to 250 g removed; depleted record deleted; test energy restored |

Processing changes the selected record's kind while preserving its ID, species, catch time, origin, owner and container. Partial consumption retains that identity. Historical unknown provenance stays unknown. Processing is a deliberate irreversible choice once completed; there is no conversion back from bait to food.

## Transaction and save rules

The kernel simulates resource changes, scheduled events and elapsed time on a private copy. It commits only a validated completed action. Missing items/fuel, remote cache access, invalid uses, an active cast/hook, time overflow or scheduled interruption leave the world unchanged. Handle a blocking interruption through Wait before retrying. Normal calendar/environment events are processed for the elapsed game time. The UI pauses and autosaves actions through its existing lifecycle path.

Schema 9 migration preserves all item records and ID sequence, changing only the inventory version. Older schema migrations continue through their existing validation and conversion paths. Products and partially eaten servings persist in saves.

## Phone test

1. Retain a fish and return to camp. Open Layers and select it.
2. Clean it. Check 10 minutes elapsed, lower mass and unchanged ID/origin.
3. Cook it. Check 15 minutes elapsed and one less wood unit. Ration calories must remain unchanged.
4. Eat it. Check five minutes elapsed and up to 250 g removed. Repeat until the record disappears.
5. Turn another catch into bait. Try eating it: expect rejection with unchanged state.
6. Save and reload a partially eaten fish; verify its ID, mass and location.
7. Try preparing away from camp or cooking without wood: expect no time/resource loss.

## Testbed limits and next gate

Preparation assumes a fixed camp work area and hearth; there is no knife requirement, fire ignition or persistent heat/fuel model yet. Cooking does not model moisture loss. Cleaning waste is a logged material sink, not a recoverable world item. Energy restoration uses one test energy point per two grams eaten (minimum one), capped at 1000; this is not a calorie/metabolism model. Freshness is recorded but does not decay. No food illness, species yield tuning, equipment durability or sales exist yet. Cut bait is stored material; selecting and consuming it in the fishing rig belongs to the next fishing/equipment gate. Ration consumption is not part of this fish-use delivery.

The next gate is causal fishing and equipment integration, including connecting stored bait to an actual rig. Camping/condition fidelity and ecology remain separate gates.
