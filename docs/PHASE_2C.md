# Phase 2C — weather, water and environmental access

Version **0.4.0**, world schema **3**, environment model **1**. Generic six-zone coastal laboratory; no dedicated geography or new species. Monetization remains absent until final release.

## Implemented boundary

1. A deterministic regional weather record driven by a repeating pressure-front forcing and a daily heating cycle.
2. Fixed laboratory tide, zone-specific depth/current/salinity/clarity/oxygen, and persistent water temperature and runoff.
3. Whole-trip environmental access checks on existing foot/wade/skiff routes, with visible reasons and unchanged fixed durations.
4. Read-only **Env** panel, zone selector, tick timestamp, and environmental observations in the existing log.
5. Validated migration of shipped Phase 2A and 2B saves without changing old clock, location, access, RNG, event IDs or history.

This is the first environmental integration test, **not the master framework's complete weather engine**. Its pressure front is prescribed, not a simulated planetary atmosphere. There is no seasonal climate, moisture conservation, storm object movement, waves, terrain flooding, local air microclimate, forecasts, survival exposure, fish behavior or biology yet. The instrument panel shows exact internal data; later player observations need their own uncertainty rules.

## Ownership and update order

`simulation/environment.gd` is scene-independent. It never reads the wall clock or global RNG. The kernel invokes it before each scheduled event and at the end of an advance. Environment changes at every aligned **five-game-minute** boundary, including every intermediate tick during movement and camp waits. A tick at a wait interruption is applied before the interruption. Calendar/marker event IDs and their existing counts remain unchanged; the environment owns its separate fixed-step timeline.

The environment record stores `version`, `initialized_at_ms`, `updated_at_ms`, `weather`, `tide`, `runoff_permille`, and `water_by_zone`. The next tick is always `updated_at_ms + 300000`; it cannot be rescheduled by the interface. Saves taken between ticks preserve that last tick and the exact clock remainder. Pausing, closing, inspecting, loading or backgrounding never advances this state.

All authoritative numeric fields are integers; JSON numbers are checked for exact integer values and normalized on load. Display conversion to decimal units happens only in the interface.

| Record field | Stored unit / meaning |
| --- | --- |
| Weather `air_temperature_centi_c` | Hundredths °C |
| `wind_deci_mps`, `wind_from_degrees` | Tenths m/s; meteorological direction the wind comes from |
| `cloud_percent` | Integer percent |
| `rain_deci_mm_hr` | Tenths mm/hour |
| `visibility_m`, `pressure_deci_hpa` | Metres; tenths hPa |
| `front_state` | Fair, approaching, passing, clearing |
| Tide `height_cm`, `phase` | Centimetres above the synthetic low-water datum; low/flood/high/ebb |
| `runoff_permille` | Bounded 0–1000 wetness/runoff proxy, not physical water volume |
| Water `depth_cm`, `current_cm_s` | Sample-zone depth in cm; current speed in cm/s |
| `current_direction` | Incoming, outgoing or slack |
| `salinity_deci_ppt`, `clarity_cm` | Tenths parts per thousand; water visibility in cm |
| `oxygen_centi_mg_l`, `temperature_centi_c` | Hundredths mg/L; hundredths °C |
| `water_present` | True for five sampled water bodies; false at elevated camp |

Dry camp has only `water_present: false`, not fabricated zero-temperature or zero-salinity water. The shallow water at sandy shore is a water sample, not the elevation of its dry foot route.

## Model fixtures, not final tuning

- The tide has a fixed 12-hour cycle: low at 06:00/18:00, high at 00:00/12:00. Rise is 80–88 cm, derived from seed. Its triangular curve and current pulses are simple test forcing, not hydrodynamics.
- A pressure trough repeats every 48 hours. Its first center is Day 1 near 18:00 (seed shifts it by up to one hour). Cloud, rain, pressure, wind and visibility share this forcing rather than rolling independent weather outcomes.
- Air responds to a fixed daily heating curve. Water approaches air temperature more slowly in larger/deeper bodies. These are integration coefficients, not calibrated physical heat budgets.
- Every tick, runoff increases with rain and drains by two units, clamped to 0–1000. Runoff persists after rain, raising water depth and reducing salinity, clarity and oxygen. Tide, wind and temperature also feed the relevant water values.
- Weather does not consume the existing Park–Miller gameplay stream. Same seed, same initial record and same time/actions give the same complete record regardless of frame partition or reload.

## Route policy

| Mode | Phase 2C test gate |
| --- | --- |
| Foot | The dry shore–camp and shore–marsh links remain open |
| Wade | Crossing depth ≤55 cm; crossing current ≤30 cm/s; visibility ≥1,000 m |
| Skiff | Existing skiff access flag; wind ≤12 m/s; visibility ≥3,000 m |

These limits are fictional gameplay fixtures, **not real-world safety guidance**. Wade crossings use their own shallow corridor depths (15 or 20 cm plus tide/runoff), not the deep channel's sampled water depth. Channel-margin current uses half the channel sample; flat crossings use the flat sample. The original topology and travel durations remain unchanged.

The kernel checks current conditions and every environmental tick through arrival on a **copy**. If any check fails, travel is refused before departure with a reason; no time, location, RNG, history or environmental state changes. Exact-limit values pass. No halfway cancellation or teleport is introduced. The map can preview routes from an inspected zone without moving the player.

Conditions can close an exit if the player lets time run after reaching a water zone. **Run clock remains available everywhere**, and closures are temporary. Accelerated 5/15/60-minute waits remain camp-only. For short phone tests, inspect water from camp instead of remaining offshore through a front. More general safe-wait/travel hazard behavior belongs to a later layer.

## Save compatibility

The envelope stays version 1; world schema changes from 2 to 3. Old records are validated against their original exact field sets **before** migration. Schema 1 also gains the Phase 2B skiff access fixture. Schema 2 preserves its skiff flag, including false.

An older world initializes the new environment at the five-minute boundary at or before its saved clock, with zero initial runoff and initialized water temperature. This is an explicit new-layer bootstrap, not a claim to have simulated environmental history that did not exist. No old game fields or offline time are altered. Future schema-3 loads restore accumulated runoff and thermal state exactly; they never bootstrap again. The UI reports migration. Existing atomic save, checksum, backup and unsupported-version protections stay in place.

## Acceptance gates

- Exact before/at-tick behavior; independent gameplay RNG; tick partition equals full-day jump.
- Full-day weather and tide phases, retained runoff after rain, zone differences and valid records at every tick.
- Rainy mid-tick save/reload and full-day future equality; seed endpoints and immutable snapshots.
- Tide/current/wind/visibility boundaries, closure before arrival, refused travel atomicity, reopening, dry route and interrupted-wait checks.
- Both legacy schemas, preservation of all original fields, one-time initialization, malformed old/new records rejected.
- Existing foreground/background, scheduler, six-zone travel, save recovery and UI gates.
- Separate operating-system process saves/reloads/continues a complete world; Android export/signature check, exported Linux launch, portrait screenshots.
- Physical phone install/update, scroll/touch, saved-state continuity and background behavior remain a **user device gate**, not something desktop tests prove.

## Next slice

After the Phase 2C phone checklist, plan the smallest ecology test: explicit population records and conservation accounting for the five approved species, zone capacity inputs, and deterministic movement/feeding influenced by environment. Do not silently add catches, inventory, survival needs, camping, 3D or monetization to that slice.
