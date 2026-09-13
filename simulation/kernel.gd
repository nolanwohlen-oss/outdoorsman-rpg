extends RefCounted
## All time and action mutations pass through this headless, deterministic kernel.

const World = preload("res://simulation/world_state.gd")
const MINUTE_MS := 60000
const MOVE_MS := 120000
const WAIT_MINUTES := [5, 15, 60]

var world: World

func _init(initial_seed: int = 13092026) -> void:
	world = World.new()
	world.seed = clampi(initial_seed, 0, World.MAX_SEED)
	world.rng_state = world.seed % (World.MAX_SEED - 1) + 1
	for kind in ["sunrise", "sunset", "midnight"]:
		_queue(World.next_calendar_time(kind, world.game_time_ms), kind, "")
	_log("world_started", "New world. Seed %d. Player at sandy shore." % world.seed)

func restore(record: Variant) -> Dictionary:
	var errors := World.validate(record)
	if not errors.is_empty():
		return _failure(" ".join(errors))
	world = World.from_record(record)
	return {"ok": true}

func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}

func _log(kind: String, detail: String) -> void:
	world.history.append({"id": world.next_log_id, "time_ms": world.game_time_ms, "kind": kind, "detail": detail})
	world.next_log_id += 1
	if world.history.size() > World.MAX_HISTORY:
		world.history.pop_front()

func _queue(due_ms: int, kind: String, label: String) -> int:
	var id := world.next_event_id
	world.next_event_id += 1
	world.scheduled.append({"id": id, "due_ms": due_ms, "kind": kind, "label": label})
	world.scheduled.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.due_ms < b.due_ms or (a.due_ms == b.due_ms and a.id < b.id))
	return id

func schedule_marker(delay_ms: int, label: String, interrupts_wait: bool = false) -> Dictionary:
	if delay_ms <= 0 or delay_ms > World.DAY_MS or label.is_empty() or label.length() > 160:
		return _failure("Marker needs a label and a delay of at most one game day.")
	if world.scheduled.size() >= World.MAX_PENDING or world.game_time_ms + delay_ms > World.MAX_TIME_MS:
		return _failure("Scheduler capacity or clock limit reached.")
	var kind := "wait_interrupt" if interrupts_wait else "marker"
	var id := _queue(world.game_time_ms + delay_ms, kind, label)
	_log("scheduled", "%s scheduled as event %d." % [label, id])
	return {"ok": true, "id": id}

func _advance(delta_ms: int, stop_wait: bool = false) -> Dictionary:
	var initial := world.game_time_ms
	var target := initial + delta_ms
	var interrupted := false
	while not world.scheduled.is_empty() and world.scheduled[0].due_ms <= target:
		var event: Dictionary = world.scheduled.pop_front()
		world.game_time_ms = int(event.due_ms)
		world.events_processed += 1
		_log(event.kind, event.label if not event.label.is_empty() else String(event.kind).capitalize())
		if World.CALENDAR.has(event.kind):
			_queue(world.game_time_ms + World.DAY_MS, event.kind, "")
		if stop_wait and event.kind == "wait_interrupt":
			interrupted = true
			target = world.game_time_ms
		# Process every event at the interruption timestamp before stopping.
	world.game_time_ms = target
	return {"ok": true, "advanced_ms": target - initial, "interrupted": interrupted}

func advance_game_ms(delta_ms: int) -> Dictionary:
	# Test/layer API. The phone UI uses approved actions, not this free-advance API.
	if delta_ms < 0 or delta_ms > World.DAY_MS or world.game_time_ms + delta_ms > World.MAX_TIME_MS:
		return _failure("Advance must be nonnegative, within one day, and within the clock limit.")
	return _advance(delta_ms)

func advance_real_us(real_us: int) -> Dictionary:
	if real_us < 0 or real_us > 14400000000:
		return _failure("Real-time input exceeds one game day at 6:1.")
	var scaled_us := real_us * 6 + world.sub_ms
	@warning_ignore("integer_division")
	var delta_ms: int = scaled_us / 1000
	if world.game_time_ms + delta_ms > World.MAX_TIME_MS:
		return _failure("Clock limit reached.")
	world.sub_ms = scaled_us % 1000
	return _advance(delta_ms)

func move(destination: String) -> Dictionary:
	if destination == world.player_zone:
		return _failure("You are already here.")
	if not destination in ["sandy_shore", "elevated_camp"]:
		return _failure("Water access is not implemented. Use the shore–camp path.")
	if world.game_time_ms + MOVE_MS > World.MAX_TIME_MS:
		return _failure("Clock limit reached.")
	var origin := world.player_zone
	_advance(MOVE_MS)
	world.player_zone = destination
	_log("move", "%s → %s. Travel: 2 game minutes." % [origin, destination])
	return {"ok": true, "message": "Moved in 2 game minutes."}

func wait_minutes(minutes: int) -> Dictionary:
	if world.player_zone != "elevated_camp":
		return _failure("Safe waiting requires elevated camp.")
	if not minutes in WAIT_MINUTES:
		return _failure("Choose a 5, 15, or 60 minute wait.")
	if world.game_time_ms + minutes * MINUTE_MS > World.MAX_TIME_MS:
		return _failure("Clock limit reached.")
	_log("wait_started", "Safe wait requested: %d game minutes." % minutes)
	var result := _advance(minutes * MINUTE_MS, true)
	_log("wait_stopped" if result.interrupted else "wait_finished", "Wait advanced %d seconds%s." % [int(result.advanced_ms / 1000), "; interrupted by scheduled event" if result.interrupted else ""])
	result.message = "Wait interrupted at scheduled event." if result.interrupted else "Wait complete."
	return result

func observe() -> Dictionary:
	_log("observe", "At %s; %s; %d pending events." % [world.player_zone, light_state(), world.scheduled.size()])
	return {"ok": true, "message": "Observation added to the log."}

func random_u31() -> int:
	# Explicit stable stream; independent of Godot/global random state and UI refreshes.
	world.rng_state = (world.rng_state * 16807) % World.MAX_SEED
	_log("random_draw", "Stream sample: %d." % world.rng_state)
	return world.rng_state

func light_state() -> String:
	var time_of_day := world.game_time_ms % World.DAY_MS
	return "Daylight" if time_of_day >= World.CALENDAR.sunrise and time_of_day < World.CALENDAR.sunset else "Night"

static func time_text(at_ms: int) -> String:
	@warning_ignore("integer_division")
	var day: int = at_ms / World.DAY_MS + 1
	@warning_ignore("integer_division")
	var seconds: int = (at_ms % World.DAY_MS) / 1000
	return "Day %d  ·  %02d:%02d:%02d" % [day, int(seconds / 3600), int(seconds / 60) % 60, seconds % 60]

func date_text() -> String:
	# Pure conversion of a fixed test epoch; never reads the device's date/time.
	var epoch := int(Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 9, "day": 13, "hour": 0, "minute": 0, "second": 0}))
	return Time.get_date_string_from_unix_time(epoch + int(world.game_time_ms / 1000))
