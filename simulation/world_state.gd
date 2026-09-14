extends RefCounted
## Authoritative Phase 2C record. It owns data, never a scene or a system clock.

const Map = preload("res://simulation/testbed_map.gd")
const CoastalEnvironment = preload("res://simulation/environment.gd")
const Ecology = preload("res://simulation/ecology.gd")
const Condition = preload("res://simulation/condition.gd")
const Inventory = preload("res://simulation/inventory.gd")
const Fishing = preload("res://simulation/fishing.gd")
const SCHEMA_VERSION := 8
const MAP_ID := "generic_coastal_testbed_v1"
const DAY_MS := 86400000
const START_MS := 21600000 # Day 1, 06:00. Fixed testbed sunrise/sunset: 06:00/18:00.
const MAX_TIME_MS := 3153600000000 # Bounded to keep all JSON integers exactly representable.
const MAX_SEED := 2147483647
const MAX_HISTORY := 200
const MAX_PENDING := 64
const ZONES := Map.ZONE_IDS
const CALENDAR := {"sunrise": 21600000, "sunset": 64800000, "midnight": 0}
const LOG_KINDS := ["world_started", "observe", "move", "wait_started", "wait_finished", "wait_stopped", "scheduled", "sunrise", "sunset", "midnight", "marker", "wait_interrupt", "random_draw", "fishing_rigged", "fishing_cast", "fish_hooked", "fish_landed"]

var seed: int = 13092026
var game_time_ms: int = START_MS
var sub_ms: int = 0 # Remainder after converting scaled real microseconds to game milliseconds.
var player_zone: String = "sandy_shore"
# A fixed channel skiff is testbed access infrastructure, not an inventory item.
var channel_skiff_available: bool = true
var environment: Dictionary = {}
var ecology: Dictionary = {}
var condition: Dictionary = {}
var inventory: Dictionary = {}
var fishing: Dictionary = {}
var rng_state: int = 1
var next_event_id: int = 1
var next_log_id: int = 1
var events_processed: int = 0
var scheduled: Array = []
var history: Array = []

static func is_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and value >= minimum and value <= maximum and value == floor(value)

static func has_keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true

static func next_calendar_time(kind: String, now_ms: int) -> int:
	@warning_ignore("integer_division")
	var next: int = (now_ms / DAY_MS) * DAY_MS + int(CALENDAR[kind])
	if next <= now_ms:
		next += DAY_MS
	return next

func to_record() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION, "map_id": MAP_ID, "map_version": Map.MAP_VERSION, "seed": seed,
		"clock": {"game_time_ms": game_time_ms, "sub_ms": sub_ms},
		"player": {"id": "player_1", "zone_id": player_zone},
		"travel": {"channel_skiff_available": channel_skiff_available},
		"environment": environment.duplicate(true),
		"ecology": ecology.duplicate(true),
		"condition": condition.duplicate(true), "inventory": inventory.duplicate(true),
		"fishing": fishing.duplicate(true),
		"random_stream": {"algorithm": "park_miller_16807_v1", "state": rng_state},
		"next_event_id": next_event_id, "next_log_id": next_log_id,
		"events_processed": events_processed,
		"scheduled_events": scheduled.duplicate(true), "history": history.duplicate(true)
	}

static func validate(record: Variant) -> PackedStringArray:
	return _validate(record, SCHEMA_VERSION)

static func _validate(record: Variant, version: int) -> PackedStringArray:
	var errors := PackedStringArray()
	var keys := ["schema_version", "map_id", "seed", "clock", "player", "random_stream", "next_event_id", "next_log_id", "events_processed", "scheduled_events", "history"]
	if version >= 2:
		keys.append_array(["map_version", "travel"])
	if version >= 3:
		keys.append("environment")
	if version >= 4:
		keys.append("ecology")
	if version >= 5:
		keys.append_array(["condition", "inventory"])
	if version >= 6:
		keys.append("fishing")
	if not has_keys(record, keys):
		return PackedStringArray(["World record has missing or unknown fields."])
	if not is_integer(record.schema_version, version, version):
		errors.append("Unsupported world schema version.")
	if record.map_id != MAP_ID or not is_integer(record.seed, 0, MAX_SEED):
		errors.append("Invalid map ID or seed.")
	if version >= 2 and not is_integer(record.map_version, Map.MAP_VERSION, Map.MAP_VERSION):
		errors.append("Invalid map version.")
	if not has_keys(record.clock, ["game_time_ms", "sub_ms"]):
		errors.append("Invalid clock record.")
	elif not is_integer(record.clock.game_time_ms, START_MS, MAX_TIME_MS) or not is_integer(record.clock.sub_ms, 0, 999):
		errors.append("Invalid clock units or range.")
	if not has_keys(record.player, ["id", "zone_id"]):
		errors.append("Invalid player record.")
	elif record.player.id != "player_1" or not record.player.zone_id in ZONES:
		errors.append("Invalid player ID or player zone.")
	if version >= 2 and (not has_keys(record.travel, ["channel_skiff_available"]) or typeof(record.travel.channel_skiff_available) != TYPE_BOOL):
		errors.append("Invalid travel access record.")
	if not has_keys(record.random_stream, ["algorithm", "state"]):
		errors.append("Invalid random stream record.")
	elif record.random_stream.algorithm != "park_miller_16807_v1" or not is_integer(record.random_stream.state, 1, MAX_SEED - 1):
		errors.append("Invalid random stream state.")
	for field in ["next_event_id", "next_log_id"]:
		if not is_integer(record[field], 1, MAX_TIME_MS):
			errors.append("Invalid ID counter: " + field)
	if not is_integer(record.events_processed, 0, MAX_TIME_MS):
		errors.append("Invalid processed event count.")
	if not record.scheduled_events is Array or not record.history is Array:
		errors.append("Event records must be arrays.")
	if not errors.is_empty():
		return errors
	if version >= 3:
		errors.append_array(CoastalEnvironment.validate(record.environment, int(record.seed), int(record.clock.game_time_ms)))
	if version >= 4:
		errors.append_array(Ecology.validate(record.ecology, int(record.seed), int(record.clock.game_time_ms)))
	if version >= 5:
		errors.append_array(Condition.validate(record.condition, int(record.clock.game_time_ms)))
		if version >= 8:
			errors.append_array(Inventory.validate(record.inventory))
		else:
			errors.append_array(Inventory.validate_legacy(record.inventory))
	if version >= 6:
		errors.append_array(Fishing.validate(record.fishing, int(record.clock.game_time_ms), version == 6))
	if record.scheduled_events.size() > MAX_PENDING or record.history.size() > MAX_HISTORY or record.history.is_empty():
		errors.append("Invalid event record count.")
	if int(record.events_processed) + record.scheduled_events.size() != int(record.next_event_id) - 1:
		errors.append("Scheduled and processed event counts do not match issued IDs.")
	if record.history.size() != mini(int(record.next_log_id) - 1, MAX_HISTORY):
		errors.append("History is incomplete for its sequence counter.")
	var ids: Dictionary = {}
	var calendar_counts := {"sunrise": 0, "sunset": 0, "midnight": 0}
	var last_due: int = -1
	var last_id: int = -1
	for event in record.scheduled_events:
		if not has_keys(event, ["id", "due_ms", "kind", "label"]):
			errors.append("Invalid scheduled event record.")
			continue
		if not is_integer(event.id, 1, int(record.next_event_id) - 1) or not is_integer(event.due_ms, int(record.clock.game_time_ms) + 1, MAX_TIME_MS + DAY_MS):
			errors.append("Invalid scheduled event ID or time.")
			continue
		if not event.kind is String or not event.kind in ["sunrise", "sunset", "midnight", "marker", "wait_interrupt"] or not event.label is String or event.label.length() > 160:
			errors.append("Unknown event kind or invalid label.")
			continue
		if ids.has(int(event.id)) or event.due_ms < last_due or (event.due_ms == last_due and event.id <= last_id):
			errors.append("Events must have unique IDs and be ordered by time, then ID.")
		ids[int(event.id)] = true
		last_due = int(event.due_ms)
		last_id = int(event.id)
		if CALENDAR.has(event.kind):
			calendar_counts[event.kind] += 1
			if event.due_ms != next_calendar_time(event.kind, int(record.clock.game_time_ms)):
				errors.append("Calendar event is not at its next boundary.")
	for count in calendar_counts.values():
		if count != 1:
			errors.append("Exactly one pending event per calendar boundary is required.")
	last_id = 0
	var last_time: int = -1
	for event in record.history:
		if not has_keys(event, ["id", "time_ms", "kind", "detail"]):
			errors.append("Invalid history record.")
			continue
		if not is_integer(event.id, 1, int(record.next_log_id) - 1) or not is_integer(event.time_ms, START_MS, int(record.clock.game_time_ms)):
			errors.append("Invalid history ID or timestamp.")
			continue
		if not event.kind in LOG_KINDS or not event.detail is String or event.detail.length() > 512:
			errors.append("Invalid history kind or detail.")
		if (last_id != 0 and event.id != last_id + 1) or event.time_ms < last_time:
			errors.append("History must have consecutive IDs and ordered times.")
		last_id = int(event.id)
		last_time = int(event.time_ms)
	if last_id != int(record.next_log_id) - 1:
		errors.append("History does not match its sequence counter.")
	return errors

static func migrate_record(record: Variant) -> Dictionary:
	if not record is Dictionary:
		return {"ok": false, "message": "World payload is not an object.", "code": "invalid"}
	var schema: Variant = record.get("schema_version")
	if is_integer(schema, SCHEMA_VERSION, SCHEMA_VERSION):
		var current_errors := validate(record)
		if not current_errors.is_empty():
			return {"ok": false, "message": " ".join(current_errors), "code": "invalid"}
		return {"ok": true, "record": record.duplicate(true), "migrated": false}
	if is_integer(schema, 1, 7):
		# Validate the old contract BEFORE adding fields; malformed/unknown fields
		# must not be silently repaired or discarded by migration.
		var legacy_errors := _validate(record, int(schema))
		if not legacy_errors.is_empty():
			return {"ok": false, "message": "Cannot migrate legacy save: " + " ".join(legacy_errors), "code": "invalid"}
		var migrated: Dictionary = record.duplicate(true)
		migrated.schema_version = SCHEMA_VERSION
		if int(schema) == 1:
			migrated.map_version = Map.MAP_VERSION
			migrated.travel = {"channel_skiff_available": true}
		if int(schema) < 3:
			migrated.environment = CoastalEnvironment.create(int(record.seed), int(record.clock.game_time_ms))
		if int(schema) < 4:
			migrated.ecology = Ecology.create(int(record.seed), int(record.clock.game_time_ms))
		if int(schema) < 5:
			migrated.condition = Condition.create(int(record.clock.game_time_ms))
			migrated.inventory = Inventory.create()
		else:
			migrated.inventory.version = Inventory.VERSION
			migrated.inventory.capacity_g = Inventory.CAPACITY_G
			migrated.inventory.items.fish_food_g = 0
		if int(schema) < 6:
			migrated.fishing = Fishing.create()
		elif int(schema) == 6:
			migrated.fishing.last_catch_weight_g = 250 if migrated.fishing.state == "hooked" else 0
			migrated.fishing.retained_count = 0
			migrated.fishing.released_count = 0
		var errors := validate(migrated)
		if not errors.is_empty():
			return {"ok": false, "message": "Cannot migrate legacy save: " + " ".join(errors), "code": "invalid"}
		return {"ok": true, "record": migrated, "migrated": true, "message": "Older save upgraded; new layers initialized at saved game time. Clock paused. No offline time added."}
	return {"ok": false, "message": "Unsupported world schema; existing files were kept.", "code": "unsupported"}

static func from_record(record: Dictionary) -> RefCounted:
	# Validation is intentionally completed before any live world is replaced.
	if not validate(record).is_empty():
		return null
	var result = load("res://simulation/world_state.gd").new()
	result.seed = int(record.seed)
	result.game_time_ms = int(record.clock.game_time_ms)
	result.sub_ms = int(record.clock.sub_ms)
	result.player_zone = record.player.zone_id
	result.channel_skiff_available = bool(record.travel.channel_skiff_available)
	result.environment = CoastalEnvironment.normalized(record.environment)
	result.ecology = Ecology.normalized(record.ecology)
	result.condition = Condition.normalized(record.condition)
	result.inventory = Inventory.normalized(record.inventory)
	result.fishing = Fishing.normalized(record.fishing)
	result.rng_state = int(record.random_stream.state)
	result.next_event_id = int(record.next_event_id)
	result.next_log_id = int(record.next_log_id)
	result.events_processed = int(record.events_processed)
	# JSON numbers arrive as floats; normalize all authoritative integer fields.
	for entry in record.scheduled_events:
		result.scheduled.append({"id": int(entry.id), "due_ms": int(entry.due_ms), "kind": entry.kind, "label": entry.label})
	for entry in record.history:
		result.history.append({"id": int(entry.id), "time_ms": int(entry.time_ms), "kind": entry.kind, "detail": entry.detail})
	return result
