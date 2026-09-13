# Simulation boundary — Phase 2A

`world_state.gd` defines and validates the authoritative versioned record. `kernel.gd` owns time, calendar events, the test movement/wait commands, and seeded random draws. `session.gd` gates foreground time. `save_store.gd` handles validated, checksummed local snapshots and backups.

The kernel runs without a UI scene. The interface submits commands; it never derives separate simulation outcomes. No wall-clock date, startup time, or saved real-world timestamp grants progression. Resumes and loads begin paused and reset the process-time baseline.

`data/testbed.json` remains the presentation catalog. Map and species names do not imply implemented habitat or population records. Full units and invariants are in `docs/PHASE_2A.md`.

Future layers must extend these contracts explicitly, schedule changes through game time, and define migrations before changing the save schema. Keep frame partition, scheduler order, random continuation, and cross-process save tests passing.
