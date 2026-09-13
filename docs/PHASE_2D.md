# Phase 2D — ecology foundation

World schema **4** adds a persistent ecology ledger for the five approved species: mullet, Atlantic menhaden, redfish, speckled trout, and black drum.

The ledger stores integer counts per zone, carrying-capacity limits, aligned 15-game-minute updates, and cumulative births, deaths, and movement. Feeding is derived from the existing water oxygen, clarity, temperature, and salinity values. Species move only along the connected map and only toward a better food condition. Counts never exceed capacity or become negative.

The kernel advances weather and ecology together at each ecology boundary. Large time jumps, hourly waits, foreground frames, movement, and save/reload continuation therefore produce the same population record. Ecology does not consume the gameplay random stream. The Env panel displays total ledger counts.

This is an accounting and response test. It does not include catching, fishing effort, individual fish, age classes, spawning seasons, harvest mortality, inventory, or player needs. Those require separate contracts after this ledger passes phone testing.

Schemas 1–3 migrate by initializing the ledger at the saved game-time boundary. No historical ecology is invented and no offline time is granted. Existing clock, map, environment, scheduler, history, travel access, and random stream fields are preserved.
