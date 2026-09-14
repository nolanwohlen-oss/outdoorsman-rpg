# Phase 2Q — presentation and strike causality

Development v0.18.0. World schema 15 / fishing record v6. This slice removes the guaranteed, premature fish selection that previously happened at cast.

## Delivered

- Casts persist an explicit `steady`, `drift`, or `soak` presentation; lure supports steady/drift and bait supports drift/soak.
- Casting no longer selects a species and no longer fails merely because the local ecology count is zero. A physically valid cast can simply produce no strike.
- A strike check occurs after the existing two-game-minute systems-lab delay. Local population, water state, rig mode and presentation feed a deterministic engagement score; there is no hidden random bite roll.
- No-strike checks keep the rig cast and schedule another two-game-minute check without spawning fish, changing ecology or consuming RNG.
- When a fish engages, the authoritative state stores the engaged species and a strike cue, but player-facing feedback exposes only the cue until the hook is set.
- Hooking reveals the species and then enters the existing fight model unchanged. Historical direct `Set hook` test paths still resolve the due strike check internally so older gate fixtures remain compatible.
- Waiting casts and developed strikes survive save/reload exactly. Phase 2P schema-14 saves migrate to schema 15 at the saved game time with no offline advancement. Existing cast/hooked Phase 2P encounters are preserved with a deterministic default presentation and strike cue.
- Current-save validation rejects incompatible presentation/rig pairs and impossible strike-cue combinations.
- Historical migration fixtures continue to model their original schemas exactly: v6-only fields are removed when constructing old records, so production migration remains strict about unknown legacy fields rather than silently accepting malformed saves.

## Systems-lab coefficients

Engagement uses deterministic prototype coefficients for rig preference, presentation, local abundance, current, clarity, salinity, oxygen, temperature and depth. They prove causal plumbing only; they are not final species behavior or catch-rate tuning. The UI intentionally does not display an engagement score or bite percentage.

## Android phone gate

1. Install the newest APK as an update and confirm `v0.18.0` / `PHASE 2Q`. Load the existing Phase 2P save and confirm the clock has not advanced while the app was closed.
2. Prepare a spoon rig. Choose **Steady**, cast, and confirm the fishing status says species is unknown and records the steady presentation.
3. Before two game minutes, tap **Read presentation / check strike** and confirm the early check is rejected without changing the cast.
4. Run/pause the clock until the strike-check time, then tap **Read presentation / check strike**. Confirm the status exposes a strike cue but still does not name the species. Save/reload and confirm presentation/cue remain unchanged.
5. Tap **Set hook**. Confirm the species is revealed only now and the existing fight controls continue normally.
6. Cancel and prepare another spoon rig. Select **Soak** and attempt to cast; confirm the incompatible presentation is rejected and the rig remains prepared.
7. If using a bait rig, confirm **Soak** or **Drift** is accepted while **Steady** is rejected.

## Deliberate limits

This gate does not implement player casting aim/trajectory, lure animation, exact sensory fields, individual fish positions, bite theft, strike expiration, hook-set timing/force, hook placement, skill/attribute resolution or final XP. Those remain later slices. The two-minute check interval and engagement coefficients are testing fixtures, not final bite physics.
