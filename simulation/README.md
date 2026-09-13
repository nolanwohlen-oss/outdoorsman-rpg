# Simulation boundary — Phase 2C

`world_state.gd` defines/validates world schema 3 and migrates schemas 1/2. `kernel.gd` owns time, events, movement/waits and gameplay RNG. `testbed_map.gd` owns the six-zone graph; `environment.gd` owns five-minute weather/water integration and access rules. `session.gd` gates foreground time. `save_store.gd` handles validated, checksummed snapshots and backups.

The kernel runs without a UI scene. The interface submits commands; it never derives separate simulation outcomes. No wall-clock date, startup time, or saved real-world timestamp grants progression. Resumes and loads begin paused and reset the process-time baseline.

`data/testbed.json` remains the presentation catalog. Habitat tags and environmental water records are implemented; listed species are not yet populations. Units, approximations, update order and access policy are in `docs/PHASE_2C.md`, with earlier kernel/map contracts in the Phase 2A/2B documents.

Future layers must extend these contracts explicitly, schedule changes through game time, and define migrations before changing the save schema. Keep frame partition, scheduler order, random continuation, and cross-process save tests passing.
