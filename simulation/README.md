# Simulation boundary

Phase 1 does not implement the simulation. The presentation catalog in `data/testbed.json` is not a world save or a canonical ecology model.

Phase 2 introduces typed, versioned records and validation. Phase 3 introduces the authoritative 6:1 clock and scheduler. Later layers depend on these contracts.

The kernel should use explicit state and commands, seeded random streams, stable identifiers, game timestamps, and auditable events. It must run without loading UI scenes. The UI should not independently calculate time, population changes, recovery, inventory mutations, or XP.

Do not read elapsed wall-clock time to grant progress at startup, load, or Android resume. Future focus/pause handling must stop advancement and discard stale frame elapsed time. Save validation and tests must precede any claims of persistence.
