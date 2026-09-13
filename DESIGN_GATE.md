# Outdoorsman RPG Design Gate

Status: approved for implementation planning

## Product direction

- First piece of a full outdoor survival RPG with layered simulation.
- The first test is a generic simulation testbed before the dedicated Grand Isle map.
- The first test prioritizes traceable system behavior and state integrity.

## Approved first test decisions

- Initial species: mullet, Atlantic menhaden, redfish, speckled trout, and black drum.
- Time scale: one real minute equals six game minutes.
- Closed game behavior: no world, ecology, condition, XP, or economy progression while the game is closed.
- Simulation detail: individual records near the player, grouped active-region records, and statistical distant-region records.
- Debug view: top-down map, state panels, and event log.
- Map representation: small connected zones with abstract coordinates.
- World size: small enough for detailed simulation on the phone.
- First actions: observe, move, wait, fish, camp, rest, sleep, save, and load.
- Data storage: local device saves with versioned records.
- Randomness: seeded deterministic randomness with a visible seed.
- Legal rules: schema and validation placeholders during the systems test.
- First-person presentation: added after the simulation kernel passes.
- Android target: primary phone first.
- Monetization: excluded from every prototype, test build, and pre-release version. Ads, premium currency, in-app purchases, subscriptions, and paid progression may be evaluated only for the final release.

## Generic test map

The first map uses six connected placeholder zones:

1. Open water
2. Tidal channel
3. Marsh edge
4. Shallow flat
5. Sandy shore
6. Elevated camp

## Implementation gate

The first coding phase is the Godot project and build shell: a runnable placeholder scene, repository structure, desktop debug target, Android export target, configuration files, and build identifiers.

Later phases add canonical data contracts, the time kernel, map and habitat, weather and water, ecology, player condition and inventory, fishing actions, camping, persistence, and scenario testing in that order.

The simulation kernel must pass deterministic time, environment, ecology, player condition, action, persistence, and save/reload tests before dedicated geography, visual polish, or release monetization work begins.
