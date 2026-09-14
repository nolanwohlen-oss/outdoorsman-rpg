# Phase 2E — player condition and inventory foundation

Phase 2E adds deterministic, versioned player condition and starter inventory records to the generic testbed. Condition updates align to the ecology boundary while the clock advances: hydration, energy, exposure, sleep debt and health use bounded integer test units. Elevated camp reduces exposure and permits limited recovery; this is a systems test, not a medical or real-world survival model.

Inventory is an explicit quantity ledger for water, food energy, firewood and bait. Fishing, consumption, crafting, equipment and carrying actions remain deferred. Older schemas migrate by initializing these records at the saved game-time boundary without granting offline progression.
