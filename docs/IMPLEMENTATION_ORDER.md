# Implementation order

This follows the approved first simulation test plan. Each phase must meet its gate before the next depends on it. Phase 1 is not the completed simulation test.

| Phase | Work | Completion gate |
| --- | --- | --- |
| 0 | Design gate | Approved decisions recorded in `DESIGN_GATE.md` |
| 1 | Godot project and build shell | Scene launches; Android APK and desktop debug build export |
| 2 | Canonical data contracts | Typed, versioned world, map, player, item, species, population, action, event, and save records reject invalid IDs/references/quantities |
| 3 | Clock and time kernel | 6:1 advancement, pause, scheduled events, safe waits; no closed/background progression |
| 4 | Generic map and habitat | Six zones have valid movement/access and habitat rules |
| 5 | Weather and water | Seeded conditions drive coherent tide, runoff, clarity, salinity, depth, and oxygen changes |
| 6 | Ecology | Five species and population/group/individual transitions conserve biological accounting |
| 7 | Player condition and inventory | Actions affect vitals, exposure, recovery, containers, items, and equipment through explicit rules |
| 8 | Fishing actions | Observe, rig, cast, hook, fight, land, release/retain, and failure produce repeatable, auditable results |
| 9 | Camping and survival | Camp, shelter, fire, water, food, rest, sleep, and storage preserve state |
| 10 | Persistence and audit | Versioned saves, atomic writes, load validation, autosave, and migrations preserve state without hidden progress |
| 11 | Scenario controls | Testers can replay seeds, environmental changes, pressure, failures, and invalid states |
| 12 | Desktop and Android validation | One simulated day passes on desktop and the primary Android phone; real device pause/resume and save/load pass |
| 13 | Review | Defects and tuning results determine the next slice |

## Phase 1 implementation choices

- Godot 4.7.2 standard edition, GDScript, Compatibility rendering.
- Portrait touch layout with scrollable panels. Desktop editor uses the same scene.
- Prototype package: `com.nolanwohlen.outdoorsman.testbed`.
- Source and configuration in GitHub; tests and exports in GitHub Actions.
- Android ARM64 debug APK and Linux x86-64 debug executable.
- Static zone inspection and seed entry are interface checks; they do not stand in for simulated weather, populations, player movement, or persistence.

## Deliberately deferred

Dedicated Grand Isle geography, first-person controls, polished assets, hunting expansion, live services, final species tuning, real legal rules, and every monetization feature remain outside this milestone. No real-money features belong in any pre-release version.

## Phase 2A delivery (user-requested coding run)

Phase 2A combines the minimum contracts from Phase 2, the clock foundation from Phase 3, and early persistence from Phase 10 so the user can test state continuity on Android now. It does not mark every numbered phase between them complete.

Implemented records cover world/map identity, player location, clock and fractional time, one explicit random stream, pending events, and bounded event history. See `PHASE_2A.md` for units, ownership, limits, versions, test fixtures, and gates.

That delivery included only the reciprocal shore–camp path (two game minutes each way), safe camp waits, fixed daylight, and scheduler markers. All six zones remained inspectable. Later lettered slices add systems without retroactively claiming that Phase 2A completed the full simulation.

## Phase 2B delivery

Phase 2B completes the generic map/habitat movement test layer: all six zones have canonical terrain/exposure/habitat records, reciprocal foot/wade/boat routes, fixed test durations, visible blocked-route reasons, and a validated Phase 2A-to-2B save migration. The channel skiff is fixed map access infrastructure, not inventory. Weather, water, ecology, player condition, fishing, camping, 3D, and monetization remain outside the delivery.

## Current position and next concrete task

Lettered slices 2C–2P now cover deterministic environmental records, five-species population accounting, coarse player condition, the fishing state machine, physical item identity and storage, explicit fish processing, persistent tackle links, the timed fish-fight/landing loop, explicit landing/post-catch condition, and deeper full-rig causality. Each phase document records its own limits and phone gate. These are connected systems-lab fixtures, not completed versions of master phases 5–8.

Phase 2P adds persistent rod/reel/line/terminal condition, deterministic full-rig wear, condition-dependent load limits, explicit loose/balanced/tight drag choices, weakest-link failure ownership, auditable failed rounds, broken-tackle rejection, and camp service/replacement. Its full code audit must pass automation and its Android checklist must pass on the physical phone before Phase 2Q depends on it. The next lettered slice is intentionally not declared complete or locked in by this roadmap until that gate closes. Camping, survival fidelity, individual wildlife behavior, the dedicated map and 3D presentation remain later gates. Passing automation does not substitute for physical Android testing or mean the complete initial survival loop is playable.
