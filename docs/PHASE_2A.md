# Phase 2A — clock and persistence foundation

Version: 0.2.0. This delivery implements the user-requested clock/save milestone on the existing Godot 4.7.2 Compatibility project. It adds the minimum data contracts needed to test changing world state. The numbered roadmap in `IMPLEMENTATION_ORDER.md` still applies to later layers.

## Observable behavior

- Start a deterministic seeded world at sandy shore, Day 1 at 06:00, paused.
- Tap Run to advance at exactly six game seconds per active real second; Pause freezes it.
- Inspect six zones. Travel between shore and elevated camp takes two game minutes.
- At elevated camp, wait 5, 15, or 60 game minutes. Waiting elsewhere or requesting other durations is rejected before any mutation.
- Calendar events and markers execute in chronological order during foreground time, travel, and waits. The scheduler test queues an interruption ten game minutes ahead; a fifteen-minute camp wait stops at that event.
- Save/Load includes the complete current kernel state. Loads and Android resumes start paused. No elapsed offline time is applied.
- Weather, water, species behavior, player needs, inventory, fishing, camping mechanics, 3D presentation, and monetization are not implemented in this milestone.

## Implementation fixtures (tuning, not real geography)

| Decision | Phase 2A value | Why |
| --- | --- | --- |
| Epoch | 2026-09-13, fixed Day 1 | A repeatable test date independent of the phone date |
| Start | 06:00 at sandy shore | Stable initial observation |
| Sunrise / sunset | 06:00 / 18:00 every day | Exercise exact day/night boundaries before seasonal/environment simulation |
| Walkable path | Sandy shore ↔ elevated camp | Known reciprocal connection; prevents walking into water before access rules exist |
| Travel cost | 120,000 game milliseconds | Explicit test cost; replace with distance/access rules in the map phase |
| Safe waiting | Camp only, 5/15/60 minutes | Bounded command inputs; future hazard/condition layers must add safety checks and interruption events |
| Calendar end | 100-year bounded clock | Keep arithmetic and JSON values within an exact, validated range |
| Audit history | Latest 200 events | Bound phone memory and save size; monotonic IDs retain ordering after truncation |
| Scheduler | At most 64 pending events | Bound test workload; reject excess before mutation |

The fixed daylight, walk duration, and safe camp are test fixtures, not claims about real-world sunrise or survival safety. Full rest/sleep and environmental danger are deferred.

## Authoritative records and units

`WorldState` is a typed GDScript RefCounted record. JSON is validated before a new record can replace the live world. Required fields are explicit; unknown fields, unknown versions, fractional integer values, booleans used as numbers, invalid references, and out-of-range values are rejected.

| Record / field | Meaning and invariant |
| --- | --- |
| `schema_version` | World schema 1; changes require an explicit migration |
| `map_id` | Exactly `generic_coastal_testbed_v1` |
| `seed` | Integer 0–2,147,483,647; changing it starts a new world |
| `clock.game_time_ms` | Integer game milliseconds since fixed Day 1 midnight; starts at 21,600,000 |
| `clock.sub_ms` | Integer remainder 0–999 after scaling real microseconds by six and dividing by 1,000; survives save/load |
| `player.id` / `zone_id` | Stable `player_1`; current accessible zone, not selected inspector zone |
| `random_stream` | Explicit Park–Miller 16807 stream, versioned algorithm name and integer state 1–2,147,483,646 |
| `scheduled_events[]` | Unique monotonic integer ID, future `due_ms`, supported event kind, bounded text label |
| `next_event_id` | Next unused event ID; issued count equals processed plus pending count |
| `events_processed` | Number executed, including recurring calendar events |
| `history[]` | Consecutive log ID, nondecreasing game timestamp, supported kind, bounded detail; latest 200 retained |
| `next_log_id` | Next unused audit ID; exactly follows last retained entry |

No item, inventory quantity, species population, or player vital records are fabricated here. Their ownership, units, accounting, and schema extensions remain part of later data-contract work.

## Time and event ordering

The kernel accepts integer foreground microseconds. It multiplies by six, advances whole game milliseconds, and retains the fractional remainder. Splitting the same active time into different frames produces the same world record. No per-frame random draws occur.

The runtime session uses monotonic process ticks, never the device date. The first frame after Run establishes a baseline. Focus loss or application pause blocks time and autosaves; focus gain/resume stays paused. Overlapping focus/suspend reasons are tracked independently. An unexpected gap over one real second pauses the clock rather than importing a stale frame.

Pending events sort by `(due_ms, id)`. Each boundary is applied once at its exact game timestamp. Sunrise, sunset, and midnight reschedule themselves one game day ahead. Interrupted waits execute all events at the interruption timestamp, then leave later events queued. The direct one-day advance API is for tests/layers and is not exposed as unrestricted waiting on the phone.

The single test random stream uses `state = state * 16807 mod 2147483647`. The seed initializes state to `seed mod 2147483646 + 1`. Its state is saved, so loading continues the next draw rather than reseeding. Future layer-specific streams require explicit records.

## Persistence and recovery

Two independent slots live in Godot's app-private `user://saves` directory: `manual.json` and `autosave.json`. Each has a `.bak` previous valid snapshot. Tests/captures inject their own directories.

A save envelope contains the format identifier, save version 1, JSON payload as text, and a SHA-256 checksum of those exact payload bytes. The checksum detects corruption; it is not an anti-cheat or authentication system. JSON integer fields are range checked and normalized to integers after parsing.

Writes validate the world, write/flush/close a temporary file, re-read and verify it, preserve an existing valid primary through a temporary backup, then rename the new primary on the same filesystem. Abandoned `.tmp` files are never loaded. A corrupt primary never replaces a good backup. This protects normal interrupted writes; it is not a guarantee against every storage hardware/power-loss failure.

Load prefers the primary. If it is corrupt or missing, a valid backup is recovered with a visible warning that it may be older. An unsupported version is rejected without silently downgrading or overwriting it. No migrations exist yet because this is the first save schema.

Manual Save pauses and records the snapshot. Load restores that snapshot without appending a world event or reseeding. New world requires a confirmation, resets autosave, and leaves the manual slot until explicitly saved over. Autosave runs after successful commands, every 30 active real seconds, on Pause, and when backgrounded. Startup restores autosave (or manual if no autosave exists) and remains paused. Unrecoverable startup saves block automatic writes until the user explicitly starts a new world.

Android may terminate a backgrounded app without a close notification. Saving on pause and regularly limits progress loss; a hard kill between autosaves can lose unsaved foreground progress. The lifecycle handling follows [Godot's mobile quit guidance](https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html).

## Verification gates

`bash tools/check.sh` checks the catalog and headless UI plus record validation, 6:1 conversion, uneven frame partitions, exact daylight/midnight boundaries, stable simultaneous events, safe wait interruption, action rejection without mutation, bounded history, fixed random reference values, save continuity, corruption/version/I/O handling, and lifecycle gating.

It then launches two separate Godot OS processes. The first plays one simulated day, saves location/time/remainder/random state/pending events/history, and records the expected future. The second restores and continues; complete current and future fingerprints must match.

GitHub Actions runs these gates, exports and verifies the signed Android debug APK, launches the exported Linux app, and captures portrait previews. Actual Android install/update, touches, Home/lock/unlock, and close/reopen are the user's remaining device gate in `PHONE_TESTING.md`.
