# Phase 2M — fish-fight and landing causality

World schema 13, inventory version 7, fishing version 4, development v0.14.0.

## Delivered

- Setting a hook creates one persistent fight record: fish stamina, line tension, fish distance, round count and a visible behavior cue. Saving and loading preserves every value and the exact rod, reel, line and terminal-tackle IDs.
- The starter test kit adds one 260 g `test_reel` and one 50 g `test_line`. A rig requires both in the pack as well as the existing rod and compatible spoon or hook.
- Each fight choice costs exactly 30 game seconds. Landing costs exactly one game minute. Rejected actions, including premature landing and capacity failure, spend no time and mutate nothing.
- Fight resolution reads fish species, mass, water temperature, oxygen and current. It does not draw from the world's random stream and does not use a hidden universal success roll.
- A fish can be landed only when stamina is at most 200 and distance is at most 250 cm. The systems-lab display states when both conditions are satisfied.
- Overload, slack-line hook pull and reaching cover are explicit causes of loss. A lost or abandoned hooked fish increments the loss counter but is not removed from the ecology population. Retention still removes exactly one local fish; release does not.
- Any prepared, cast or hooked rig locks travel, resource use and inventory transfer until the encounter is completed or cancelled. This prevents linked physical equipment from becoming stranded or invalid.
- Every action remains auditable in the event log. `fish_fight` records the chosen response and resulting values; `fish_lost` records the cause.

## Current test rules

| Visible cue | Intended response | Test effect |
| --- | --- | --- |
| Surge | Give line | Reduces tension while the fish gains some distance |
| Pull | Hold pressure | Drains stamina while maintaining controlled tension |
| Slack | Reel in | Recovers line and closes distance |
| Tired | Reel in | Brings an exhausted fish toward landing range |

Wrong responses are not a disguised percentage roll. Pressuring or reeling into a surge can overload the tackle; giving line while slack can pull the hook; repeatedly yielding distance can let the fish reach cover.

The exact starting stamina and distance are deterministic test formulas, not biological claims or final balance. The exact numeric readout is a systems-lab instrument and is not the intended final player HUD.

## Save migration

Schemas 1–12 are validated before conversion. Existing item IDs, fish provenance, counters, time, environment, ecology and history are preserved. Schema 12 receives one reel and one line with new item IDs; a hooked schema-12 encounter keeps its species and weight and gains deterministic fight state at the saved conditions.

If an old active encounter has a completely full pack, the added rig parts go to camp and cannot validly remain linked. Migration therefore closes only that encounter, records one loss if a fish was already hooked, and preserves the inventory and ecology unchanged. It likewise closes a Phase 2L prepared rig saved in a different zone from the player, an old state that Phase 2M no longer permits. The load message states why closure occurred. This avoids rejecting an otherwise valid old save, silently exceeding pack capacity or retaining an impossible remote rig.

## Phone acceptance test

1. Install the newest successful APK as an update and load the existing world. The footer must show `v0.14.0`. In Layers, confirm one `test_reel` and one `test_line` were added without replacing existing item IDs.
2. At a water zone, prepare a spoon rig and cast. Run the clock until two game minutes have passed, pause it, and tap **Set hook**. The status must show species, mass, cue, stamina, tension, distance and fight-choice count.
3. Before fighting, confirm both landing buttons are disabled. Follow the displayed test rule: **Surge → Give line**, **Pull → Hold pressure**, **Slack/Tired → Reel in**.
4. After each choice, confirm the clock advances 30 game seconds, the choice count increases by one and the next cue appears. Pause/save/load during a fight; all displayed values and the current cue must return exactly, with the clock paused.
5. Continue until `READY TO LAND` appears. The fight buttons must disable and both landing buttons must enable. Retain or release; the action must advance one game minute and return the fishing state to idle.
6. For a failure test, start another fight. When a **Surge** cue appears, tap **Hold pressure** or **Reel in**. The result must name excessive tension, increment **Lost**, return to idle and allow another rig. The ecology count must not drop merely because the fish escaped.
7. Prepare a rig but do not cast. Try **Go to camp** and a Map trip; travel must be blocked. Cancel fishing and confirm travel works again.
8. At camp, store the test reel, return to water and attempt to prepare a rig. It must reject the incomplete rig without changing time or inventory. Return the same reel to the pack and retry successfully.

Report the footer build number, exact step, expected and actual result, and a screenshot for any failure.

## Deliberate limits and next gate

This is a causal systems test, not final fishing physics. It does not yet model adjustable drag, rod angle, line stretch, knots, leaders, hook geometry, equipment durability, broken-item records, individual fish memory, jumping/rolling animations, player footing, landing nets or gaffs, handling injury, release mortality, regulations, or player exertion stamina. No tackle item is consumed by the current failure outcomes. The cue-response mapping and thresholds are temporary testing values.

The proposed next gate is landing method and post-catch condition, including explicit handling/release consequences and recoverable tackle condition or loss. It should be approved after this Android checklist passes.
