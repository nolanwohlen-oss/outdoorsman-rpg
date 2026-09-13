# Phase 2B — six-zone movement and habitat testbed

Version 0.3.0. Phase 2B turns the generic test map into a deterministic traversal layer while retaining the Phase 2A clock, scheduler, pause behavior, and local save rules.

`simulation/testbed_map.gd` is the authoritative map contract. The JSON catalog remains presentation data for names, colors, and layout. No weather, water state, population, player vital, inventory, fishing, camping, 3D, or monetization system is active here.

| Link | Mode | Fixed test duration | Access fixture |
| --- | --- | ---: | --- |
| Elevated camp ↔ Sandy shore | Foot | 2 min | Dune track |
| Sandy shore ↔ Marsh edge | Foot | 4 min | Firm shoreline |
| Sandy shore ↔ Shallow flat | Wade | 6 min | Marked firm-flat crossing |
| Marsh edge ↔ Tidal channel | Wade | 5 min | Firm marsh margin |
| Shallow flat ↔ Tidal channel | Wade | 4 min | Marked firm-flat crossing |
| Tidal channel ↔ Open water | Boat | 12 min | Fixed test skiff staged at the channel launch |

Every route is reciprocal. The durations and firm crossings are controlled test fixtures; they deliberately do not claim real travel safety, water depth, tide, current, or boat handling. Open water is reachable only after reaching tidal channel. Selecting a non-adjacent zone shows a blocked reason and cannot mutate time, location, history, or saves.

Each zone now carries terrain, exposure, habitat tags, and potential species IDs. These are classification records for later ecology and action work. Potential species display is not a fish population, spawn table, catch chance, or simulation result.

## Save compatibility

World schema 2 adds `map_version` and a `travel.channel_skiff_available` flag. Schema-1 Phase 2A saves load through a validated migration: old shore/camp location, time, scheduler, random stream, and history are preserved; the fixed channel skiff is added as available. The app then creates a current autosave. Unknown future schemas remain blocked and are not overwritten automatically.

## Verification

The automated gates validate the map graph, reciprocal routes, six-zone reachability, route durations/modes, direct-route blocking with no mutation, skiff requirement blocking, save/load replay, legacy-save migration, UI route/blocked indicators, and all Phase 2A clock/persistence/lifecycle checks.
