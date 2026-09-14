# Phase 2K — equipment-driven fishing

World schema 11, inventory version 5, development v0.12.0.

The test kit now contains a stable test rod and spoon item. Fishing state records whether the rig uses a lure or a selected cut-bait item. Preparing a bait rig requires cut bait in the carried pack; casting consumes 50 g from that exact item and preserves its identity until depleted. Lure rigs consume no bait. Rig state survives saves and is cleared safely by cancellation.

Old schemas validate before conversion. Fishing version 1 records gain explicit lure state during migration. Inventory versions 3 and 4 gain the test equipment records only when absent; existing item IDs and provenance remain intact.

Phone test: prepare a catch as bait at camp, travel to water, prepare the bait rig, cast, and confirm the bait mass decreases. Repeat until depleted, then confirm the bait rig is rejected. Prepare a lure rig and confirm it casts without bait. Save while rigged and reload; the selected mode must remain. Cancel an encounter and confirm travel is available.

Limits: rod and spoon are fixed test equipment, without durability, line, hook, leader, reel, slot compatibility, or species-specific suitability. Bait consumption is a 50 g test transaction. The encounter remains deterministic scaffolding. Equipment slots, tackle compatibility, failure causality and richer fight/landing choices remain later work.
