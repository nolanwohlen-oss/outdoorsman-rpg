extends RefCounted
## All time and action mutations pass through this headless, deterministic kernel.

const World = preload("res://simulation/world_state.gd")
const Map = preload("res://simulation/testbed_map.gd")
const CoastalEnvironment = preload("res://simulation/environment.gd")
const Ecology = preload("res://simulation/ecology.gd")
const Condition = preload("res://simulation/condition.gd")
const Inventory = preload("res://simulation/inventory.gd")
const Fishing = preload("res://simulation/fishing.gd")
const MINUTE_MS := 60000
const WAIT_MINUTES := [5, 15, 60]

var world: World

func _advance_layers_to(target_ms: int) -> void:
	var next := int(world.ecology.updated_at_ms) + Ecology.STEP_MS
	while next <= target_ms:
		CoastalEnvironment.advance_to(world.environment, world.seed, next)
		Ecology.advance_to(world.ecology, world.seed, next, world.environment)
		Condition.advance_to(world.condition, next, world.player_zone, world.environment)
		next += Ecology.STEP_MS
	CoastalEnvironment.advance_to(world.environment, world.seed, target_ms)
	Condition.advance_to(world.condition, target_ms, world.player_zone, world.environment)

func _init(initial_seed: int = 13092026) -> void:
	world = World.new()
	world.seed = clampi(initial_seed, 0, World.MAX_SEED)
	world.rng_state = world.seed % (World.MAX_SEED - 1) + 1
	world.environment = CoastalEnvironment.create(world.seed, world.game_time_ms)
	world.ecology = Ecology.create(world.seed, world.game_time_ms)
	world.condition = Condition.create(world.game_time_ms)
	world.inventory = Inventory.create()
	world.fishing = Fishing.create()
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
		# Environmental ticks at this instant occur before action/calendar events.
		_advance_layers_to(world.game_time_ms)
		world.events_processed += 1
		_log(event.kind, event.label if not event.label.is_empty() else String(event.kind).capitalize())
		if World.CALENDAR.has(event.kind):
			_queue(world.game_time_ms + World.DAY_MS, event.kind, "")
		if stop_wait and event.kind == "wait_interrupt":
			interrupted = true
			target = world.game_time_ms
		# Process every event at the interruption timestamp before stopping.
	world.game_time_ms = target
	_advance_layers_to(target)
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
	if world.fishing.state in ["cast", "hooked"]:
		return _failure("Finish or cancel fishing before travelling.")
	var resolution := travel_result(destination)
	if not resolution.ok:
		return _failure(resolution.reason)
	var route: Dictionary = resolution.route
	var duration_ms: int = int(route.minutes) * MINUTE_MS
	if world.game_time_ms + duration_ms > World.MAX_TIME_MS:
		return _failure("Clock limit reached.")
	var origin := world.player_zone
	_advance(duration_ms)
	world.player_zone = destination
	_log("move", "%s → %s by %s. Travel: %d game minutes." % [origin, destination, route.mode, int(route.minutes)])
	return {"ok": true, "route": route.duplicate(true), "message": "Moved by %s in %d game minutes." % [route.mode, int(route.minutes)]}

func travel_result(destination: String) -> Dictionary:
	return route_preview(world.player_zone, destination)

func route_preview(origin: String, destination: String) -> Dictionary:
	var result := Map.travel_result(origin, destination, {"channel_skiff_available": world.channel_skiff_available})
	if not result.ok:
		return result
	var arrival := world.game_time_ms + int(result.route.minutes) * MINUTE_MS
	if arrival > World.MAX_TIME_MS:
		return {"ok": false, "reason": "Clock limit reached."}
	var reason := CoastalEnvironment.route_block(result.route, world.environment)
	if not reason.is_empty():
		return {"ok": false, "reason": reason}
	# Validate the whole fixed-duration trip on a copy. An inspector or failed
	# command cannot advance real state or consume RNG. No mid-trip teleport.
	var preview := world.environment.duplicate(true)
	while int(preview.updated_at_ms) + CoastalEnvironment.STEP_MS <= arrival:
		CoastalEnvironment.advance_to(preview, world.seed, int(preview.updated_at_ms) + CoastalEnvironment.STEP_MS)
		reason = CoastalEnvironment.route_block(result.route, preview)
		if not reason.is_empty():
			return {"ok": false, "reason": "Would close before arrival (%s): %s" % [time_text(int(preview.updated_at_ms)), reason]}
	return result

func route_plan(destination: String) -> Dictionary:
	var path := Map.shortest_path(world.player_zone, destination)
	if path.size() < 2:
		return {"ok": false, "reason": "Choose a different destination."}
	var legs: Array = []
	var total := 0
	var simulated := world.environment.duplicate(true)
	var origin: String = path[0]
	for index in range(1, path.size()):
		var next: String = path[index]
		var base := Map.travel_result(origin, next, {"channel_skiff_available": world.channel_skiff_available})
		if not base.ok:
			return base
		var reason := CoastalEnvironment.route_block(base.route, simulated)
		if not reason.is_empty():
			return {"ok": false, "reason": "Route closes at %s: %s" % [Map.ZONES[origin].id, reason]}
		total += int(base.route.minutes) * MINUTE_MS
		var arrival := world.game_time_ms + total
		if arrival > World.MAX_TIME_MS:
			return {"ok": false, "reason": "Clock limit reached."}
		var preview := simulated.duplicate(true)
		while int(preview.updated_at_ms) + CoastalEnvironment.STEP_MS <= arrival:
			CoastalEnvironment.advance_to(preview, world.seed, int(preview.updated_at_ms) + CoastalEnvironment.STEP_MS)
			reason = CoastalEnvironment.route_block(base.route, preview)
			if not reason.is_empty():
				return {"ok": false, "reason": "Route would close before arrival at %s: %s" % [Map.ZONES[next].id, reason]}
		legs.append(base.route.duplicate(true))
		simulated = preview
		origin = next
	return {"ok": true, "path": path, "legs": legs, "minutes": int(total / MINUTE_MS)}

func move_plan(destination: String) -> Dictionary:
	if world.fishing.state in ["cast", "hooked"]:
		return _failure("Finish or cancel fishing before travelling.")
	var plan := route_plan(destination)
	if not plan.ok:
		return plan
	for leg in plan.legs:
		var result := move(String(leg.to))
		if not result.ok:
			return result
	return {"ok": true, "message": "Trip complete: %d game minutes across %d legs." % [plan.minutes, plan.legs.size()], "plan": plan}

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
	var env: Dictionary = world.environment
	_log("observe", "At %s; %s; front %s; tide %s (%d cm); wind %.1f m/s; runoff %d/1000. CoastalEnvironment tick: %s." % [world.player_zone, light_state(), env.weather.front_state, env.tide.phase, env.tide.height_cm, float(env.weather.wind_deci_mps) / 10.0, env.runoff_permille, time_text(int(env.updated_at_ms))])
	return {"ok": true, "message": "Observation added to the log."}

func rig_fishing(use_bait: bool = false) -> Dictionary:
	if world.fishing.state in ["cast", "hooked"]:
		return _failure("Finish or cancel the current fishing encounter first.")
	if world.player_zone == "elevated_camp" or not world.environment.water_by_zone[world.player_zone].water_present:
		return _failure("Fishing requires a water zone.")
	var bait_id := ""
	if use_bait:
		bait_id = Inventory.carried_id(world.inventory, "cut_bait")
		if bait_id.is_empty():
			return _failure("Carry prepared cut bait before choosing a bait rig.")
	world.fishing.state = "rigged"
	world.fishing.zone = world.player_zone
	world.fishing.target_species = ""
	world.fishing.bite_due_ms = 0
	world.fishing.rig_mode = "bait" if use_bait else "lure"
	world.fishing.bait_item_id = bait_id
	_log("fishing_rigged", "Rig prepared at %s." % world.player_zone)
	return {"ok": true, "message": "Rig prepared."}

func cast_fishing() -> Dictionary:
	if world.fishing.state != "rigged" or world.fishing.zone != world.player_zone:
		return _failure("Prepare a rig at your current water zone first.")
	var choices: Array = []
	for species in Fishing.SPECIES:
		if int(world.ecology.populations[species].get(world.player_zone, 0)) > 0:
			choices.append(species)
	if choices.is_empty():
		return _failure("No test population is present here.")
	if world.fishing.rig_mode == "bait":
		if not world.inventory.entries.has(world.fishing.bait_item_id) or world.inventory.entries[world.fishing.bait_item_id].container != "pack":
			return _failure("Selected bait is no longer in the pack.")
		world.inventory.entries[world.fishing.bait_item_id].mass_g = maxi(0, int(world.inventory.entries[world.fishing.bait_item_id].mass_g) - 50)
		if world.inventory.entries[world.fishing.bait_item_id].mass_g == 0:
			world.inventory.entries.erase(world.fishing.bait_item_id)
	world.fishing.state = "cast"
	world.fishing.target_species = choices[posmod(world.seed + world.game_time_ms, choices.size())]
	world.fishing.bite_due_ms = world.game_time_ms + 15 * MINUTE_MS
	_log("fishing_cast", "Cast into %s; bite window opens in 15 game minutes." % world.player_zone)
	return {"ok": true, "message": "Cast complete. Check for a bite after 15 game minutes."}

func hook_fishing() -> Dictionary:
	if world.fishing.zone != world.player_zone:
		return _failure("Return to the encounter zone or cancel fishing.")
	if world.fishing.state != "cast":
		return _failure("Nothing is waiting on the line.")
	if world.game_time_ms < int(world.fishing.bite_due_ms):
		return _failure("No bite yet; keep the line out.")
	world.fishing.state = "hooked"
	world.fishing.last_catch_weight_g = 250 + posmod(world.seed + world.game_time_ms + world.player_zone.length() * 31, 1750)
	_log("fish_hooked", "Hook set on %s." % world.fishing.target_species)
	return {"ok": true, "message": "Fish hooked: %s." % world.fishing.target_species}

func land_fishing(retain: bool) -> Dictionary:
	if world.fishing.zone != world.player_zone:
		return _failure("Return to the encounter zone or cancel fishing.")
	if world.fishing.state != "hooked":
		return _failure("Set a hook before landing a fish.")
	var species: String = world.fishing.target_species
	var weight: int = int(world.fishing.last_catch_weight_g)
	if retain:
		var available: int = int(world.ecology.populations[species].get(world.player_zone, 0))
		if available <= 0:
			return _failure("The fish was lost before landing.")
		var stored := Inventory.add_fish(world.inventory, species, weight, world.game_time_ms, world.player_zone)
		if not stored.ok:
			return _failure("The fish is too large for the available carry capacity.")
		world.fishing.retained_count += 1
		world.ecology.populations[species][world.player_zone] = available - 1
	else:
		world.fishing.released_count += 1
	world.condition.energy = maxi(0, int(world.condition.energy) - 3)
	world.condition.hydration = maxi(0, int(world.condition.hydration) - 1)
	world.fishing.last_outcome = ("retained " if retain else "released ") + "%s (%dg)" % [species, weight]
	world.fishing.state = "idle"
	_log("fish_landed", world.fishing.last_outcome.capitalize() + ".")
	return {"ok": true, "message": "Fish %s: %s." % ["retained" if retain else "released", species]}

func transfer_inventory(id: String, destination: String) -> Dictionary:
	var result := Inventory.transfer(world.inventory, id, destination, world.player_zone)
	if result.ok:
		_log("observe", result.message)
	return result

func use_inventory(id: String, action: String) -> Dictionary:
	if world.fishing.state in ["cast", "hooked"]:
		return _failure("Finish or cancel fishing before handling resources.")
	# Evaluate time, events and resources together before committing any state.
	var candidate = get_script().new(world.seed)
	var restored: Dictionary = candidate.restore(world.to_record())
	if not restored.ok:
		return _failure("Cannot start action from invalid world state.")
	var result := Inventory.use_item(candidate.world.inventory, id, action, world.player_zone)
	if not result.ok:
		return result
	var duration: int = int(result.minutes) * MINUTE_MS
	if world.game_time_ms > World.MAX_TIME_MS - duration:
		return _failure("Action exceeds the supported clock range.")
	var elapsed: Dictionary = candidate._advance(duration, true)
	if not elapsed.ok or elapsed.interrupted:
		return _failure("A scheduled interruption blocks this action. Wait through it before retrying; no resources or time were spent.")
	candidate.world.condition.energy = mini(1000, int(candidate.world.condition.energy) + int(result.energy))
	candidate._log("observe", result.message)
	var errors := World.validate(candidate.world.to_record())
	if not errors.is_empty():
		return _failure("Action validation failed; world unchanged.")
	world = candidate.world
	return {"ok": true, "message": result.message}

func cancel_fishing() -> Dictionary:
	if not world.fishing.state in ["cast", "hooked", "rigged"]:
		return _failure("No fishing encounter to cancel.")
	world.fishing.state = "idle"
	world.fishing.last_outcome = "Fishing cancelled; no fish retained."
	_log("observe", world.fishing.last_outcome)
	return {"ok": true, "message": world.fishing.last_outcome}

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
