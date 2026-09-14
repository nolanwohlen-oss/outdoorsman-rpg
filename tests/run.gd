extends SceneTree
## Behavioral gates: conservation of time, replay, persistence, and lifecycle.

const Catalog = preload("res://scripts/catalog.gd")
const World = preload("res://simulation/world_state.gd")
const Kernel = preload("res://simulation/kernel.gd")
const Session = preload("res://simulation/session.gd")
const SaveStore = preload("res://simulation/save_store.gd")
const Map = preload("res://simulation/testbed_map.gd")
const CoastalEnvironment = preload("res://simulation/environment.gd")
const Inventory = preload("res://simulation/inventory.gd")
var failures := 0
var checks := 0
var test_directory: String

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, explanation: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(explanation)

func same(a: Kernel, b: Kernel) -> bool:
	return SaveStore.fingerprint(a.world.to_record()) == SaveStore.fingerprint(b.world.to_record())

func _contracts() -> void:
	var k := Kernel.new(42)
	var record := k.world.to_record()
	check(World.validate(record).is_empty(), "Fresh world must validate.")
	check(k.world.game_time_ms == 21600000 and k.world.player_zone == "sandy_shore", "World begins at shore at 06:00.")
	for invalid in [null, [], {}, "world"]:
		check(not World.validate(invalid).is_empty(), "Non-record input is rejected.")
	var mutations: Array[Dictionary] = []
	var bad := record.duplicate(true)
	bad.clock.game_time_ms = 1.5
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.clock.sub_ms = 1000
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.player.zone_id = "missing_zone"
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.random_stream.state = 0
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.seed = true
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.schema_version = World.SCHEMA_VERSION + 1
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.unknown_field = "must not silently discard"
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.scheduled_events[1].id = bad.scheduled_events[0].id
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.scheduled_events[0].due_ms = record.clock.game_time_ms
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.scheduled_events.pop_back()
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.next_log_id = 100
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.scheduled_events.reverse()
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.history[0].time_ms = World.MAX_TIME_MS
	mutations.append(bad)
	for invalid in mutations:
		check(not k.restore(invalid).ok and k.world.to_record() == record, "Invalid restore is rejected without partial mutation.")
	var legacy: Dictionary = record.duplicate(true)
	legacy.erase("environment")
	legacy.erase("ecology")
	legacy.erase("condition")
	legacy.erase("inventory")
	legacy.erase("fishing")
	legacy.erase("condition")
	legacy.erase("inventory")
	legacy.erase("map_version")
	legacy.erase("travel")
	legacy.schema_version = 1
	var migration := World.migrate_record(legacy)
	check(migration.ok and migration.migrated and migration.record.schema_version == World.SCHEMA_VERSION and migration.record.travel.channel_skiff_available, "Phase 2A save migrates to the current travel/environment schema.")

func _map_and_travel() -> void:
	check(Map.validate().is_empty(), "Canonical six-zone map and reciprocal route graph validate.")
	var k := Kernel.new(42)
	var camp_plan := k.route_plan("elevated_camp")
	check(camp_plan.ok and camp_plan.legs.size() == 1 and camp_plan.minutes == 2, "A one-tap destination plan returns its leg list and total time.")
	check(k.move_plan("elevated_camp").ok and k.world.player_zone == "elevated_camp" and k.world.game_time_ms == World.START_MS + 2 * Kernel.MINUTE_MS, "A planned trip executes all legs as one user action.")
	k = Kernel.new(42)
	var before: Dictionary = k.world.to_record()
	check(not k.move("open_water").ok and k.world.to_record() == before, "Non-adjacent travel is blocked without time, location, or log mutation.")
	check(not k.move("unknown").ok and k.world.to_record() == before, "Unknown destination is blocked without mutation.")
	check(k.move("marsh_edge").ok and k.world.game_time_ms == World.START_MS + 4 * Kernel.MINUTE_MS, "Foot route uses its explicit four-minute duration.")
	check(k.move("tidal_channel").ok and k.world.game_time_ms == World.START_MS + 9 * Kernel.MINUTE_MS, "Wade route adds its explicit five-minute duration.")
	check(k.move("open_water").ok and k.world.game_time_ms == World.START_MS + 21 * Kernel.MINUTE_MS, "Boat route reaches open water through the channel skiff access.")
	check(k.world.player_zone == "open_water" and World.validate(k.world.to_record()).is_empty(), "Every reached zone remains valid and saveable.")
	k.world.channel_skiff_available = false
	before = k.world.to_record()
	check(not k.move("tidal_channel").ok and k.world.to_record() == before, "Unavailable channel skiff blocks a boat link without mutation.")
	var a := Kernel.new(42)
	var b := Kernel.new(42)
	for destination in ["shallow_flat", "tidal_channel", "open_water"]:
		a.move(destination)
		b.move(destination)
	var decoded := SaveStore.decode(SaveStore.encode(a.world.to_record()))
	check(decoded.ok and b.restore(decoded.record).ok and same(a, b), "Travel route history and access state survive a save/load round trip.")

func _clock_and_scheduler() -> void:
	var a := Kernel.new(42)
	var b := Kernel.new(42)
	a.advance_real_us(60000000)
	for i in 6000:
		b.advance_real_us(10000)
	check(a.world.game_time_ms == World.START_MS + 360000, "One real minute advances exactly six game minutes.")
	check(same(a, b), "Frame partitions must produce identical complete records.")
	a = Kernel.new(42)
	b = Kernel.new(42)
	var sum := 0
	for microseconds in [1, 7, 16789, 231, 800002, 121, 19]:
		a.advance_real_us(microseconds)
		sum += microseconds
	b.advance_real_us(sum)
	check(same(a, b), "Sub-millisecond time is conserved across uneven input frames.")
	var before := a.world.to_record()
	check(not a.advance_real_us(-1).ok and a.world.to_record() == before, "Negative time never mutates state.")
	check(not a.advance_game_ms(World.DAY_MS + 1).ok and a.world.to_record() == before, "Unbounded jump is rejected atomically.")
	a = Kernel.new(42)
	b = Kernel.new(42)
	a.schedule_marker(600000, "first")
	a.schedule_marker(600000, "second")
	b.restore(a.world.to_record())
	a.advance_game_ms(World.DAY_MS)
	for hour in 24:
		b.advance_game_ms(3600000)
	check(same(a, b), "One day in one step equals 24 hourly steps, including all events.")
	check(a.world.events_processed == 5, "Both markers and three calendar events fire exactly once.")
	check(a.world.history[3].detail == "first" and a.world.history[4].detail == "second", "Same-time events use insertion IDs for stable order.")
	check(a.light_state() == "Daylight" and a.date_text() == "2026-09-14", "Next sunrise and calendar date advance coherently.")
	check(World.validate(a.world.to_record()).is_empty(), "Day rollover preserves record invariants.")
	a = Kernel.new(0)
	a.advance_game_ms(12 * 3600000 - 1)
	check(a.light_state() == "Daylight", "Millisecond before sunset remains daylight.")
	a.advance_game_ms(1)
	check(a.light_state() == "Night", "Sunset changes light at the exact boundary.")
	a.advance_game_ms(6 * 3600000)
	check(Kernel.time_text(a.world.game_time_ms) == "Day 2  ·  00:00:00", "Midnight rolls into the next day.")
	check(a.world.scheduled[0].kind == "sunrise", "Scheduler points to the next sunrise after midnight.")

func _actions() -> void:
	var k := Kernel.new(42)
	var before := k.world.to_record()
	check(not k.wait_minutes(15).ok and k.world.to_record() == before, "Waiting at shore is rejected without hidden time or log changes.")
	check(not k.move("open_water").ok and k.world.to_record() == before, "Missing water access cannot be bypassed by movement.")
	check(not k.move("unknown").ok and k.world.to_record() == before, "Unknown zone is rejected.")
	check(k.move("elevated_camp").ok and k.world.game_time_ms == 21720000, "Travel to camp costs two game minutes.")
	before = k.world.to_record()
	check(not k.move("elevated_camp").ok and k.world.to_record() == before, "No-op movement does not consume time.")
	check(not k.wait_minutes(1440).ok and k.world.to_record() == before, "The action API rejects unrestricted waits.")
	k.move("sandy_shore")
	k.move("shallow_flat")
	k.move("tidal_channel")
	check(k.rig_fishing().ok and k.cast_fishing().ok, "Fishing rig and cast require a valid water zone and create an encounter.")
	check(not k.hook_fishing().ok, "A bite cannot be set before its deterministic window.")
	k.advance_game_ms(15 * Kernel.MINUTE_MS)
	check(k.hook_fishing().ok and k.world.fishing.state == "hooked", "The deterministic bite window produces a hookable encounter.")
	var fish_food_before: int = Inventory.quantity(k.world.inventory, "fish_food_g")
	var fish_species: String = k.world.fishing.target_species
	var fish_before: int = int(k.world.ecology.populations[fish_species][k.world.player_zone])
	check(k.land_fishing(true).ok and k.world.fishing.state == "idle" and Inventory.quantity(k.world.inventory, "fish_food_g") > fish_food_before and Inventory.quantity(k.world.inventory, "food_kcal") == 4000 and k.world.fishing.retained_count == 1 and k.world.fishing.last_catch_weight_g >= 250 and int(k.world.ecology.populations[fish_species][k.world.player_zone]) == fish_before - 1, "Landing and retaining a fish stores raw fish weight and removes one fish from the local population.")
	k.move_plan("elevated_camp")
	k.schedule_marker(600000, "stop here", true)
	k.schedule_marker(600000, "same instant")
	k.schedule_marker(660000, "later")
	var waited := k.wait_minutes(15)
	check(waited.ok and waited.interrupted and waited.advanced_ms == 600000, "Scheduled interruption stops a wait after ten minutes.")
	check(k.world.events_processed == 2 and k.world.scheduled[0].label == "later", "All events at interruption fire; later events remain queued.")
	check(World.validate(k.world.to_record()).is_empty(), "Interrupted state remains valid and saveable.")
	check(k.wait_minutes(5).ok and k.world.events_processed == 3, "Next wait processes the remaining event exactly once.")
	var now := k.world.game_time_ms
	k.observe()
	check(k.world.game_time_ms == now and k.world.history.back().kind == "observe", "Observe records state without advancing time.")
	var day := Kernel.new(42)
	day.move("elevated_camp")
	for hour in 24:
		day.wait_minutes(60)
	check(day.world.game_time_ms == 108120000 and day.world.events_processed == 3, "A full day through safe waits processes sunset, midnight, sunrise.")
	for i in 250:
		day.observe()
	check(day.world.history.size() == 200 and World.validate(day.world.to_record()).is_empty(), "Audit log stays bounded with consecutive IDs.")

func _random_and_replay() -> void:
	var a := Kernel.new(0)
	check(a.random_u31() == 16807 and a.random_u31() == 282475249, "Random stream matches fixed reference values.")
	a.advance_real_us(1)
	a.schedule_marker(17, "saved marker")
	var decoded := SaveStore.decode(SaveStore.encode(a.world.to_record()))
	check(decoded.ok, "Serialized payload decodes and validates.")
	if not decoded.ok:
		return
	var b := Kernel.new(999)
	b.restore(decoded.record)
	check(same(a, b) and b.world.sub_ms == 6, "Round trip preserves every record field and fractional clock time.")
	for i in 12:
		check(a.random_u31() == b.random_u31(), "Loaded stream preserves its next random draw.")
	a.advance_real_us(12345)
	b.advance_real_us(12345)
	check(same(a, b), "Resume produces the same future as uninterrupted play.")
	check(not same(Kernel.new(1), Kernel.new(2)), "Different seeds produce distinct states.")

func _save_files() -> void:
	var store := SaveStore.new(test_directory.path_join("slots"))
	var k := Kernel.new(7)
	var first := k.world.to_record()
	check(store.save_slot("manual", first).ok, "First save writes verified primary bytes.")
	check(store.load_slot("manual").record == first, "Disk round trip restores the complete record.")
	var legacy: Dictionary = first.duplicate(true)
	legacy.erase("environment")
	legacy.erase("ecology")
	legacy.erase("condition")
	legacy.erase("inventory")
	legacy.erase("fishing")
	legacy.erase("map_version")
	legacy.erase("travel")
	legacy.schema_version = 1
	var migrated := SaveStore.decode(SaveStore.encode(legacy))
	check(migrated.ok and migrated.migrated and migrated.record.player.zone_id == "sandy_shore", "Legacy save envelope migrates through the save store without losing location.")
	k.move("elevated_camp")
	k.wait_minutes(60)
	var second := k.world.to_record()
	check(store.save_slot("manual", second).ok, "Subsequent save atomically replaces primary and preserves backup.")
	check(store.load_slot("manual").record == second, "Newest valid primary takes priority over backup.")
	store._write(store.path_for("manual") + ".tmp", "interrupted write")
	check(store.load_slot("manual").record == second, "Abandoned temporary files cannot replace a committed save.")
	store._write(store.path_for("manual"), "{broken")
	var recovered := store.load_slot("manual")
	check(recovered.ok and recovered.recovered and recovered.record == first, "Corrupt primary recovers the prior backup explicitly.")
	check(store.save_slot("manual", second).ok, "A recovered world can be saved normally.")
	check(store._read(store.path_for("manual") + ".bak").record == first, "Corrupt primary never overwrites a good backup.")
	var envelope: Dictionary = JSON.parse_string(SaveStore.encode(second))
	envelope.payload += " "
	check(not SaveStore.decode(JSON.stringify(envelope)).ok, "Checksum detects changed payload bytes.")
	envelope = JSON.parse_string(SaveStore.encode(second))
	envelope.save_version = 999
	var future := JSON.stringify(envelope)
	store._write(store.path_for("manual"), future)
	check(store.load_slot("manual").code == "unsupported", "Unknown save version is not silently rolled back to an old backup.")
	check(not store.save_slot("manual", first).ok and FileAccess.get_file_as_string(store.path_for("manual")) == future, "Automatic saving cannot overwrite an unsupported version.")
	check(store.save_slot("manual", first, true).ok, "Explicit reset permits replacing an unsupported save.")
	var invalid := first.duplicate(true)
	invalid.player.zone_id = "missing"
	check(not store.save_slot("manual", invalid).ok and store.load_slot("manual").record == first, "Invalid state cannot replace a valid save.")
	check(not store.load_slot("../../escape").ok, "Slot names cannot escape the save directory.")
	var io_store := SaveStore.new(test_directory.path_join("blocked"))
	DirAccess.make_dir_recursive_absolute(io_store.directory)
	DirAccess.make_dir_recursive_absolute(io_store.path_for("manual") + ".tmp")
	check(not io_store.save_slot("manual", first).ok, "Write failure is reported without claiming a successful save.")
	var no_backup := SaveStore.new(test_directory.path_join("corrupt_only"))
	DirAccess.make_dir_recursive_absolute(no_backup.directory)
	no_backup._write(no_backup.path_for("manual"), "broken")
	check(not no_backup.load_slot("manual").ok, "Corruption without backup is a visible error, not a new world.")

func _session_lifecycle() -> void:
	var k := Kernel.new(42)
	var session := Session.new(k)
	session.sample(1000000)
	check(k.world.game_time_ms == World.START_MS, "Fresh session begins paused.")
	session.set_running(true)
	session.sample(900000000)
	check(k.world.game_time_ms == World.START_MS, "First frame starts an active baseline without counting prior uptime.")
	session.sample(900500000)
	check(k.world.game_time_ms == World.START_MS + 3000, "Foreground active sampling respects 6:1.")
	session.suspend("focus")
	session.suspend("suspend")
	var before := k.world.to_record()
	session.sample(900000000000)
	session.resume("focus")
	session.set_running(true)
	check(not session.running and k.world.to_record() == before, "Focus alone cannot resume an application that remains suspended.")
	session.resume("suspend")
	session.sample(910000000000)
	check(not session.running and k.world.to_record() == before, "Resume stays paused with no offline progression.")
	session.set_running(true)
	session.sample(910000000000)
	session.sample(910000500000)
	check(k.world.game_time_ms == int(before.clock.game_time_ms) + 3000, "Only newly active time counts after a fresh Run tap.")
	before = k.world.to_record()
	check(not session.sample(920000000000).ok and not session.running and k.world.to_record() == before, "Unexpected long frame pauses rather than granting stale time.")

func _ui() -> void:
	# Multi-leg destination planner regression coverage.
	var catalog := Catalog.read()
	check(Catalog.validate(catalog).is_empty() and catalog.zones.size() == 6 and catalog.species.size() == 5 and catalog.layers.size() == 9, "Approved map, species and layer catalog remains intact.")
	var lookup: Dictionary = {}
	for zone in catalog.zones:
		lookup[zone.id] = zone
	var visited: Dictionary = {}
	var remaining: Array = ["sandy_shore"]
	while not remaining.is_empty():
		var current: String = remaining.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		for neighbor in lookup[current].neighbors:
			remaining.append(neighbor)
	check(visited.size() == 6, "All catalog zones remain connected.")
	var invalid := catalog.duplicate(true)
	invalid.zones[0].neighbors.append("missing_zone")
	check(not Catalog.validate(invalid).is_empty(), "Unknown catalog connections remain rejected.")
	invalid = catalog.duplicate(true)
	invalid.species.append(invalid.species[0].duplicate())
	check(not Catalog.validate(invalid).is_empty(), "Duplicate catalog species remain rejected.")
	var app = load("res://scenes/main.tscn").instantiate()
	app.save_directory = test_directory.path_join("app")
	root.add_child(app)
	await process_frame
	check(app.tabs.get_tab_count() == 5 and app.zone_buttons.size() == 6, "Clock, Map, Env, Layers, Log and six zones launch.")
	check(app.move_button.get_index() < app.inspector_body.get_index(), "Phone travel control precedes long habitat and route details.")
	var initial = app.kernel.world.to_record()
	for zone in catalog.zones:
		app.zone_buttons[zone.id].pressed.emit()
		check(app.selected_zone_id == zone.id and app.inspector_title.text == zone.name, "Every zone is inspectable by touch.")
	check(app.kernel.world.to_record() == initial, "Map inspection cannot move the player or advance simulation.")
	app.environment_zone.item_selected.emit(0)
	check(app.selected_zone_id == "open_water" and app.water_label.text.contains("600 cm") and app.kernel.world.to_record() == initial, "Environment zone picker displays live water without moving or mutating state.")
	app.select_zone("elevated_camp")
	check(app.water_label.text.contains("not applicable"), "Environment panel does not invent water at dry camp.")
	app.select_zone("marsh_edge")
	check(not app.move_button.disabled and app.route_label.text.contains("Foot"), "Map inspector exposes a direct foot route and enabled travel control.")
	app.select_zone("open_water")
	check(app.move_button.disabled and (app.route_label.text.contains("Full route") or app.route_label.text.contains("Blocked")), "Map inspector explains non-adjacent travel or offers its full route instead of allowing a hidden jump.")
	app.select_zone("marsh_edge")
	app._move_selected()
	check(app.kernel.world.player_zone == "marsh_edge", "Map travel control moves to a connected zone.")
	app._move_to("tidal_channel")
	app._move_to("open_water")
	check(app.kernel.world.player_zone == "open_water" and app.location_label.text.contains("Open water"), "UI can reach boat-only open water through the channel link.")
	check(app.wait_buttons[0].disabled, "Unsafe waiting remains disabled away from camp.")
	app._move_to("elevated_camp")
	check(app.kernel.world.player_zone == "elevated_camp" and app.location_label.text.contains("Elevated camp") and not app.wait_buttons[0].disabled, "Clock Go to camp executes the complete return route from open water and enables safe waiting.")
	app._wait(15)
	app._save_manual()
	var saved = app.kernel.world.to_record()
	check(not app.session.running and app.save_label.text.contains("State"), "Save pauses the app and reports its snapshot fingerprint.")
	app._wait(60)
	app._load_manual()
	check(app.kernel.world.to_record() == saved, "UI Load restores exactly without appending a fake world event.")
	app.notification(NOTIFICATION_APPLICATION_PAUSED)
	app.session.sample(999999999999)
	app.notification(NOTIFICATION_APPLICATION_RESUMED)
	check(not app.session.running and app.kernel.world.to_record() == saved, "App pause/resume notifications preserve the complete world.")
	check(app.saves.load_slot("autosave").record == saved, "Background notification persists the exact current world.")
	app.queue_free()
	await process_frame
	app = load("res://scenes/main.tscn").instantiate()
	app.save_directory = test_directory.path_join("app")
	root.add_child(app)
	await process_frame
	check(app.kernel.world.to_record() == saved and not app.session.running, "A newly created app restores autosave and starts paused.")
	app.seed_input.get_line_edit().text = "123"
	app._new_world()
	check(app.kernel.world.seed == 123 and app.kernel.world.game_time_ms == World.START_MS, "New world applies the entered seed and resets the clock.")
	check(app.saves.load_slot("manual").record == saved, "New world does not delete the manual save.")
	app.kernel.advance_game_ms(6 * 3600000)
	app._refresh()
	app.select_zone("shallow_flat")
	check(app.move_button.disabled and app.route_label.text.contains("depth") and app.weather_label.text.contains("High"), "High-tide environment and blocked travel reason agree in the UI.")
	app.kernel.advance_game_ms(6 * 3600000)
	app._process(0.0)
	check(app.last_environment_tick == app.kernel.world.environment.updated_at_ms and app.weather_label.text.contains("Low"), "Tick refresh updates environment and routes while the panel is open.")
	var probe := Kernel.new(42)
	var crossing := Map.route("sandy_shore", "shallow_flat")
	for step in 72:
		probe.advance_game_ms(CoastalEnvironment.STEP_MS)
		if not CoastalEnvironment.route_block(crossing, probe.world.environment).is_empty():
			break
	var departure_limit := probe.world.game_time_ms - int(crossing.minutes) * Kernel.MINUTE_MS
	app.kernel = Kernel.new(42)
	app.session.kernel = app.kernel
	app.kernel.advance_game_ms(departure_limit - World.START_MS - 1000)
	app.select_zone("shallow_flat")
	app._refresh()
	check(not app.move_button.disabled, "UI permits departure just before the whole-trip closure window.")
	var old_tick: int = app.kernel.world.environment.updated_at_ms
	app.kernel.advance_game_ms(1000)
	app._process(0.0)
	check(app.kernel.world.environment.updated_at_ms == old_tick and app.move_button.disabled and app.route_label.text.contains("before arrival"), "UI updates a departure-window closure even without a new environment tick.")
	app.queue_free()
	await process_frame

func _environment() -> void:
	var a := Kernel.new(42)
	var b := Kernel.new(42)
	var initial := a.world.environment.duplicate(true)
	a.advance_game_ms(CoastalEnvironment.STEP_MS - 1)
	check(a.world.environment == initial, "Environment stays constant until its exact five-minute boundary.")
	a.advance_game_ms(1)
	check(a.world.environment.updated_at_ms == World.START_MS + CoastalEnvironment.STEP_MS and a.world.environment != initial, "Environment advances once at the tick, not once per frame.")
	check(a.world.rng_state == b.world.rng_state, "Weather never consumes the gameplay random stream.")
	a = Kernel.new(42)
	var rain_seen := false
	var runoff_after_rain := false
	var fronts: Dictionary = {}
	var tide_phases: Dictionary = {}
	var all_valid := true
	for step in 288:
		a.advance_game_ms(CoastalEnvironment.STEP_MS)
		var env: Dictionary = a.world.environment
		fronts[env.weather.front_state] = true
		tide_phases[env.tide.phase] = true
		rain_seen = rain_seen or env.weather.rain_deci_mm_hr > 0
		runoff_after_rain = runoff_after_rain or (rain_seen and env.weather.rain_deci_mm_hr == 0 and env.runoff_permille > 0)
		all_valid = all_valid and World.validate(a.world.to_record()).is_empty()
	b.advance_game_ms(World.DAY_MS)
	check(same(a, b), "288 environment steps equal a one-day jump in the complete world record.")
	check(all_valid, "Every tick through a full day has valid units and coupled water records.")
	check(fronts.size() == 4 and rain_seen, "A seeded front approaches, passes, clears and returns to fair weather with rain.")
	check(tide_phases.size() == 4, "A full day visits low, flood, high, and ebb tide phases.")
	check(runoff_after_rain, "Runoff persists after rain stops rather than resetting with weather.")
	check(a.world.environment.water_by_zone.open_water.temperature_centi_c != a.world.environment.water_by_zone.shallow_flat.temperature_centi_c, "Different water-body inertia creates distinct zone temperatures.")
	check(a.world.environment.water_by_zone.open_water.depth_cm > a.world.environment.water_by_zone.marsh_edge.depth_cm and not a.world.environment.water_by_zone.elevated_camp.water_present, "Deep water, shallow margins and dry camp are distinct.")
	check(CoastalEnvironment.tide_at(42, 12 * 3600000).height_cm == 86 and CoastalEnvironment.tide_at(42, 18 * 3600000).height_cm == 0, "Tide matches fixed seed-42 high/low reference heights.")
	a = Kernel.new(42)
	a.advance_game_ms(11 * 3600000 + 123)
	a.advance_real_us(1)
	var checkpoint := a.world.to_record()
	var decoded := SaveStore.decode(SaveStore.encode(checkpoint))
	check(decoded.ok and b.restore(decoded.record).ok and same(a, b), "A rainy mid-tick save preserves environment, runoff and fractional clock exactly.")
	var saved_water: Dictionary = a.world.environment.water_by_zone.duplicate(true)
	a.advance_game_ms(World.DAY_MS)
	for hour in 24:
		b.advance_game_ms(3600000)
	check(same(a, b), "A reloaded environment continues identically for another full day.")
	check(checkpoint.environment.water_by_zone == saved_water, "Advancing live water cannot mutate an earlier snapshot.")
	var different := Kernel.new(43)
	different.advance_game_ms(6 * 3600000)
	check(different.world.environment.tide.height_cm != CoastalEnvironment.tide_at(42, 12 * 3600000).height_cm, "Seed changes tide amplitude even when fresh low-water conditions initially match.")
	for seed in [0, 1, 2147483647]:
		var edge := Kernel.new(seed)
		edge.advance_game_ms(World.DAY_MS)
		check(World.validate(edge.world.to_record()).is_empty(), "Minimum/maximum seeds remain valid after a day.")
	var invalid: Array = []
	var bad := checkpoint.duplicate(true)
	bad.environment.updated_at_ms += 1
	invalid.append(bad)
	bad = checkpoint.duplicate(true)
	bad.environment.version = 2
	invalid.append(bad)
	bad = checkpoint.duplicate(true)
	bad.environment.initialized_at_ms = -1
	invalid.append(bad)
	bad = checkpoint.duplicate(true)
	bad.environment.runoff_permille = true
	invalid.append(bad)
	bad = checkpoint.duplicate(true)
	bad.environment.weather.wind_deci_mps = INF
	invalid.append(bad)
	bad = checkpoint.duplicate(true)
	bad.environment.weather.cloud_percent = -1
	invalid.append(bad)
	bad = checkpoint.duplicate(true)
	bad.environment.tide.phase = "unknown"
	invalid.append(bad)
	bad = checkpoint.duplicate(true)
	bad.environment.water_by_zone.open_water.salinity_deci_ppt = 12.5
	invalid.append(bad)
	bad = checkpoint.duplicate(true)
	bad.environment.water_by_zone.open_water.temperature_centi_c = NAN
	invalid.append(bad)
	bad = checkpoint.duplicate(true)
	bad.environment.water_by_zone.marsh_edge.erase("oxygen_centi_mg_l")
	invalid.append(bad)
	bad = checkpoint.duplicate(true)
	bad.environment.water_by_zone.elevated_camp.water_present = 0
	invalid.append(bad)
	bad = checkpoint.duplicate(true)
	bad.environment.weather.unknown = 1
	invalid.append(bad)
	bad = checkpoint.duplicate(true)
	bad.environment.water_by_zone.erase("sandy_shore")
	invalid.append(bad)
	bad = checkpoint.duplicate(true)
	bad.environment = []
	invalid.append(bad)
	var before := a.world.to_record()
	for record in invalid:
		check(not a.restore(record).ok and a.world.to_record() == before, "Malformed environment restore is rejected without partial mutation.")

func _environment_access() -> void:
	var k := Kernel.new(42)
	k.advance_game_ms(6 * 3600000)
	var before := k.world.to_record()
	check(not k.move("shallow_flat").ok and k.travel_result("shallow_flat").reason.contains("depth") and k.world.to_record() == before, "High tide rejects wading with its depth reason and no state changes.")
	check(k.move("elevated_camp").ok, "Dry camp route remains open at high tide.")
	k.advance_game_ms(6 * 3600000)
	check(not k.route_preview("tidal_channel", "open_water").ok and k.route_preview("tidal_channel", "open_water").reason.contains("Wind"), "Passing front closes the skiff route with a wind reason.")
	k.advance_game_ms(12 * 3600000)
	check(k.route_preview("sandy_shore", "shallow_flat").ok and k.route_preview("tidal_channel", "open_water").ok, "Wading and skiff routes reopen after tide/front/runoff conditions ease.")
	var route := Map.route("sandy_shore", "shallow_flat")
	var fixture := CoastalEnvironment.create(42, World.START_MS)
	fixture.tide.height_cm = 35
	fixture.water_by_zone.shallow_flat.current_cm_s = 30
	check(CoastalEnvironment.route_block(route, fixture).is_empty(), "Wade depth/current exactly at the configured limits pass.")
	fixture.water_by_zone.shallow_flat.current_cm_s = 31
	check(CoastalEnvironment.route_block(route, fixture).contains("current"), "Current one cm/s beyond the limit rejects wading.")
	fixture.water_by_zone.shallow_flat.current_cm_s = 0
	fixture.tide.height_cm = 36
	check(CoastalEnvironment.route_block(route, fixture).contains("depth"), "Depth one cm beyond the limit rejects wading.")
	fixture = CoastalEnvironment.create(42, World.START_MS)
	fixture.weather.wind_deci_mps = 120
	var boat := Map.route("tidal_channel", "open_water")
	check(CoastalEnvironment.route_block(boat, fixture).is_empty(), "Skiff wind exactly at the test limit passes.")
	fixture.weather.wind_deci_mps = 121
	check(CoastalEnvironment.route_block(boat, fixture).contains("Wind"), "Skiff wind one tenth m/s beyond the limit fails.")
	fixture.weather.wind_deci_mps = 30
	fixture.weather.visibility_m = 2999
	check(CoastalEnvironment.route_block(boat, fixture).contains("Visibility"), "Poor-visibility skiff guard rejects its boundary fixture.")
	k = Kernel.new(42)
	var predicted := false
	for step in 72:
		if CoastalEnvironment.route_block(route, k.world.environment).is_empty() and not k.travel_result("shallow_flat").ok:
			before = k.world.to_record()
			predicted = k.travel_result("shallow_flat").reason.contains("before arrival")
			check(not k.move("shallow_flat").ok and k.world.to_record() == before, "A crossing that would close en route is rejected atomically before departure.")
			break
		k.advance_game_ms(CoastalEnvironment.STEP_MS)
	check(predicted, "Whole-trip preview catches a future closure while current conditions are still open.")
	k = Kernel.new(42)
	k.move("elevated_camp")
	k.schedule_marker(8 * Kernel.MINUTE_MS, "on environment boundary", true)
	k.wait_minutes(15)
	check(k.world.environment.updated_at_ms == k.world.game_time_ms and World.validate(k.world.to_record()).is_empty(), "A wait interrupted on an environment tick processes that tick exactly once.")

func _environment_migrations() -> void:
	var original := Kernel.new(123)
	original.move("elevated_camp")
	original.wait_minutes(60)
	original.random_u31()
	original.advance_real_us(1)
	original.schedule_marker(600000, "legacy pending event")
	for schema in [1, 2]:
		var legacy := original.world.to_record()
		legacy.erase("environment")
		legacy.erase("ecology")
		legacy.erase("condition")
		legacy.erase("inventory")
		legacy.erase("fishing")
		legacy.schema_version = schema
		if schema == 1:
			legacy.erase("map_version")
			legacy.erase("travel")
		else:
			legacy.travel.channel_skiff_available = false
		var result := SaveStore.decode(SaveStore.encode(legacy))
		check(result.ok and result.migrated, "Both shipped schema 1 and schema 2 save envelopes migrate.")
		if not result.ok:
			continue
		var all_preserved := true
		for key in legacy:
			if key != "schema_version":
				all_preserved = all_preserved and legacy[key] == result.record[key]
		check(all_preserved, "Migration preserves every legacy clock, location, RNG, log, event and access field.")
		check(result.record.environment.initialized_at_ms == CoastalEnvironment.tick_at(original.world.game_time_ms) and result.record.environment.runoff_permille == 0, "Legacy weather initializes at saved game time without retroactive rain or offline replay.")
		check(not SaveStore.decode(SaveStore.encode(result.record)).migrated, "Schema 3 round trip does not reinitialize its environment.")
		legacy.environment = {}
		check(not World.migrate_record(legacy).ok, "Unknown old-schema fields are rejected, not laundered through migration.")
	var limit := original.world.to_record()
	limit.schema_version = 2
	limit.erase("environment")
	limit.clock.game_time_ms = World.MAX_TIME_MS
	limit.scheduled_events.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.id < y.id)
	# A malformed legacy payload must stay rejected even at the clock bound.
	check(not World.migrate_record(limit).ok, "Migration never repairs invalid legacy calendar events.")

func _inventory_records() -> void:
	_fish_uses()
	var k := Kernel.new(42)
	check(Inventory.total_weight_g(k.world.inventory) == 4520, "Ration mass is separate from calories.")
	var result := Inventory.add_fish(k.world.inventory, "mullet", 800, k.world.game_time_ms, k.world.player_zone)
	check(result.ok, "An individual catch is stored.")
	var id: String = result.id
	var fish: Dictionary = k.world.inventory.entries[id].duplicate(true)
	check(fish.quantity == 1 and fish.mass_g == 800 and fish.species == "mullet" and fish.origin == k.world.player_zone, "Fish record preserves identity, mass and origin.")
	check(Inventory.quantity(k.world.inventory, "food_kcal") == 4000, "Fish never become ration calories automatically.")
	var before := k.world.to_record()
	check(not k.transfer_inventory(id, "camp").ok and k.world.to_record() == before, "Remote storage transfer is rejected without mutation.")
	k.move_plan("elevated_camp")
	check(k.transfer_inventory(id, "camp").ok and Inventory.total_weight_g(k.world.inventory) == 4520, "Camp transfer removes carried mass.")
	check(k.world.inventory.entries[id].species == fish.species and k.world.inventory.entries[id].caught_ms == fish.caught_ms, "Transfer preserves catch provenance and identity.")
	var loaded := Kernel.new(99)
	check(loaded.restore(JSON.parse_string(JSON.stringify(k.world.to_record()))).ok and same(k, loaded), "Physical items and storage survive JSON save and reload.")
	check(k.transfer_inventory(id, "pack").ok and k.world.inventory.entries[id] == fish, "Taking a catch back restores the same object record.")
	for field in ["quantity", "mass_g", "condition", "caught_ms"]:
		var bad := k.world.to_record()
		bad.inventory.entries[id][field] = true
		check(not World.validate(bad).is_empty(), "Item numeric fields reject boolean corruption.")
	for field in ["owner", "container", "species", "kind", "origin"]:
		var bad := k.world.to_record()
		bad.inventory.entries[id][field] = "invalid"
		check(not World.validate(bad).is_empty(), "Invalid item references are rejected.")
	var bad: Dictionary = k.world.to_record()
	bad.inventory.next_id = 1
	check(not World.validate(bad).is_empty(), "Item ID sequence cannot be reused.")
	bad = k.world.to_record()
	bad.inventory.entries[id].caught_ms = k.world.game_time_ms + 1
	check(not World.validate(bad).is_empty(), "Future catch times are rejected.")
	k.transfer_inventory(id, "camp")
	Inventory.add_fish(k.world.inventory, "mullet", 14000, k.world.game_time_ms, k.world.player_zone)
	before = k.world.to_record()
	check(k.transfer_inventory(id, "pack").ok and Inventory.total_weight_g(k.world.inventory) <= Inventory.CAPACITY_G, "A stored item can return to the pack within its capacity.")
	check(not k.transfer_inventory("missing", "camp").ok, "Unknown item cannot be transferred.")
	check(Inventory.validate(k.world.inventory).is_empty(), "Valid inventory remains valid after rejected operations.")
	k = Kernel.new(42)
	k.move_plan("elevated_camp")
	for index in 5:
		var catch_result := Inventory.add_fish(k.world.inventory, "mullet", 10000, k.world.game_time_ms, k.world.player_zone)
		check(catch_result.ok and k.transfer_inventory(catch_result.id, "camp").ok, "Separate catches can fill camp storage up to its limit.")
	check(k.world.inventory.entries.size() == 10 and Inventory.total_weight_g(k.world.inventory, "camp") == 50000, "Each fish retains a distinct ID in a full cache.")
	var extra := Inventory.add_fish(k.world.inventory, "mullet", 100, k.world.game_time_ms, k.world.player_zone)
	before = k.world.to_record()
	check(not k.transfer_inventory(extra.id, "camp").ok and k.world.to_record() == before, "Full cache rejects transfer atomically.")

func _fish_uses() -> void:
	var k := Kernel.new(42)
	var caught := Inventory.add_fish(k.world.inventory, "mullet", 1000, k.world.game_time_ms, k.world.player_zone)
	var id: String = caught.id
	var original: Dictionary = k.world.inventory.entries[id].duplicate(true)
	var before := k.world.to_record()
	check(not k.use_inventory(id, "eat").ok and k.world.to_record() == before, "Raw fish cannot be eaten and rejection is atomic.")
	check(not k.use_inventory(id, "clean").ok and k.world.to_record() == before, "Preparation requires camp.")
	k.move_plan("elevated_camp")
	var start: int = k.world.game_time_ms
	check(k.use_inventory(id, "clean").ok and k.world.game_time_ms == start + 10 * Kernel.MINUTE_MS, "Cleaning spends ten game minutes.")
	check(k.world.inventory.entries[id].mass_g == 600 and k.world.inventory.entries[id].kind == "cleaned_fish", "Cleaning has an explicit bounded yield.")
	check(k.world.inventory.entries[id].caught_ms == original.caught_ms and k.world.inventory.entries[id].species == original.species, "Processing retains source identity and provenance.")
	var wood := Inventory.quantity(k.world.inventory, "firewood_units")
	start = k.world.game_time_ms
	check(k.use_inventory(id, "cook").ok and k.world.game_time_ms == start + 15 * Kernel.MINUTE_MS and Inventory.quantity(k.world.inventory, "firewood_units") == wood - 1, "Cooking spends time and one wood unit.")
	check(Inventory.quantity(k.world.inventory, "food_kcal") == 4000, "Prepared fish remains separate from ration counters.")
	k.world.condition.energy = 400
	start = k.world.game_time_ms
	check(k.use_inventory(id, "eat").ok and k.world.game_time_ms == start + 5 * Kernel.MINUTE_MS and k.world.inventory.entries[id].mass_g == 350 and k.world.condition.energy > 400, "Eating consumes a 250 g portion and restores test energy.")
	var loaded := Kernel.new(99)
	check(loaded.restore(JSON.parse_string(JSON.stringify(k.world.to_record()))).ok and same(k, loaded), "Partially consumed products persist exactly.")
	check(k.use_inventory(id, "eat").ok and k.use_inventory(id, "eat").ok and not k.world.inventory.entries.has(id), "Last serving removes the depleted record.")
	before = k.world.to_record()
	check(not k.use_inventory(id, "eat").ok and k.world.to_record() == before, "Consumed fish cannot be reused.")
	caught = Inventory.add_fish(k.world.inventory, "mullet", 800, k.world.game_time_ms, k.world.player_zone)
	id = caught.id
	check(k.use_inventory(id, "bait").ok and k.world.inventory.entries[id].mass_g == 800, "Bait preparation preserves material mass.")
	before = k.world.to_record()
	check(not k.use_inventory(id, "eat").ok and k.world.to_record() == before, "Cut bait is not food.")
	caught = Inventory.add_fish(k.world.inventory, "mullet", 800, k.world.game_time_ms, k.world.player_zone)
	id = caught.id
	k.schedule_marker(Kernel.MINUTE_MS, "Stop preparation", true)
	before = k.world.to_record()
	check(not k.use_inventory(id, "clean").ok and k.world.to_record() == before, "Interrupted preparation spends no resources or time.")
	k.wait_minutes(5)
	check(k.use_inventory(id, "clean").ok, "Preparation can resume after the blocking event is handled.")
	for key in k.world.inventory.entries.keys():
		if k.world.inventory.entries[key].kind == "firewood_units":
			k.world.inventory.entries.erase(key)
	before = k.world.to_record()
	check(not k.use_inventory(id, "cook").ok and k.world.to_record() == before, "Missing fuel rejects cooking atomically.")
	var bait_catch := Inventory.add_fish(k.world.inventory, "mullet", 800, k.world.game_time_ms, k.world.player_zone)
	var bait_id: String = bait_catch.id
	check(k.use_inventory(bait_id, "bait").ok, "A catch can be prepared as rig bait.")
	k.move_plan("sandy_shore")
	var bait_mass := int(k.world.inventory.entries[bait_id].mass_g)
	check(k.rig_fishing(true).ok and k.world.fishing.rig_mode == "bait", "Bait rig requires and records a carried cut-bait item.")
	var cast_result := k.cast_fishing()
	check(cast_result.ok, "Casting a bait rig succeeds with the selected item.")
	check(k.cancel_fishing().ok, "Bait encounter can be cancelled without consuming the remaining rig state.")
	var legacy := k.world.to_record()
	legacy.schema_version = 9
	legacy.inventory.version = 3
	legacy.fishing.version = 1
	legacy.fishing.erase("rig_mode")
	legacy.fishing.erase("bait_item_id")
	for key in legacy.inventory.entries.keys():
		if legacy.inventory.entries[key].kind in ["test_rod", "test_spoon"]:
			legacy.inventory.entries.erase(key)
	for key in legacy.inventory.entries.keys():
		if legacy.inventory.entries[key].kind in Inventory.PRODUCTS:
			legacy.inventory.entries.erase(key)
	var upgraded: Dictionary = World.migrate_record(legacy)
	check(upgraded.ok and upgraded.record.inventory.entries == legacy.inventory.entries and upgraded.record.inventory.next_id == legacy.inventory.next_id, "Schema 9 migration preserves physical items and ID sequence.")

func _audit_regressions() -> void:
	_inventory_records()
	var k := Kernel.new(42)
	k.advance_game_ms(World.DAY_MS)
	k.world.condition.health = 654
	k.world.fishing.retained_count = 3
	for version in [4, 5, 6, 7, 8]:
		var old: Dictionary = k.world.to_record()
		old.schema_version = version
		if version < 5:
			old.erase("condition")
			old.erase("inventory")
		else:
			old.inventory = {"version": 1, "items": {"water_ml": 777, "food_kcal": 4000, "firewood_units": 12, "bait_units": 0}}
			if version == 8:
				old.inventory.version = 2
				old.inventory.capacity_g = 15000
				old.inventory.items.fish_food_g = 900
		if version < 6:
			old.erase("fishing")
		else:
			old.fishing.version = 1
			old.fishing.erase("rig_mode")
			old.fishing.erase("bait_item_id")
		if version == 6:
			for key in ["last_catch_weight_g", "retained_count", "released_count"]:
				old.fishing.erase(key)
		var snapshot: Dictionary = old.duplicate(true)
		var migrated: Dictionary = World.migrate_record(old)
		check(migrated.ok and old == snapshot, "Shipped legacy schema migrates without mutating its input.")
		if migrated.ok:
			check(migrated.record.ecology == old.ecology, "Migration preserves existing population and counters.")
			if version >= 5:
				check(migrated.record.condition == old.condition and Inventory.quantity(migrated.record.inventory, "water_ml") == 777, "Migration preserves player condition and depleted inventory.")
			if version == 8:
				check(Inventory.quantity(migrated.record.inventory, "legacy_fish") == 900, "Migration preserves pooled fish without inventing identities.")
			if version == 7:
				check(migrated.record.fishing.state == old.fishing.state and migrated.record.fishing.zone == old.fishing.zone and migrated.record.fishing.target_species == old.fishing.target_species and migrated.record.fishing.last_outcome == old.fishing.last_outcome, "Migration preserves encounter and catch history.")
	k = Kernel.new(42)
	k.rig_fishing()
	k.cast_fishing()
	var before: Dictionary = k.world.to_record()
	check(not k.move_plan("elevated_camp").ok and k.world.to_record() == before, "Travelling with a cast line is rejected atomically.")
	check(not k.rig_fishing().ok and k.world.to_record() == before, "Re-rigging cannot overwrite an active encounter.")
	k.advance_game_ms(15 * Kernel.MINUTE_MS)
	k.hook_fishing()
	for entry in k.world.inventory.entries.values():
		entry.container = "camp"
	var full_catch := Inventory.add_fish(k.world.inventory, "mullet", 15000, k.world.game_time_ms, k.world.player_zone)
	check(full_catch.ok, "A full-size catch can occupy the available pack capacity.")
	before = k.world.to_record()
	check(not k.land_fishing(true).ok and k.world.to_record() == before, "Full inventory rejects retention without changing fish, counters, or vitals.")
	check(k.land_fishing(false).ok, "A fish can still be released when inventory is full.")
	k.rig_fishing()
	check(k.world.fishing.released_count == 1, "Preparing another rig preserves cumulative catch counts.")
	check(k.cancel_fishing().ok and k.move_plan("elevated_camp").ok, "Cancellation restores a travel recovery path.")
	for field in ["version", "bite_due_ms", "retained_count"]:
		var bad: Dictionary = k.world.to_record()
		bad.fishing[field] = true
		check(not World.validate(bad).is_empty(), "Fishing numeric fields reject booleans.")
	var ecology = load("res://simulation/ecology.gd")
	var e: Dictionary = ecology.create(42, World.START_MS)
	for species in ecology.SPECIES:
		for zone in ecology.CAPACITY[species]:
			e.populations[species][zone] = ecology.CAPACITY[species][zone]
	var initial_total := 0
	for species in ecology.SPECIES:
		initial_total += ecology.total(e, species)
	var env := CoastalEnvironment.create(42, World.START_MS)
	for step in 192:
		var target: int = int(e.updated_at_ms) + ecology.STEP_MS
		CoastalEnvironment.advance_to(env, 42, target)
		ecology.advance_to(e, 42, target, env)
	var final_total := 0
	for species in ecology.SPECIES:
		final_total += ecology.total(e, species)
	check(final_total == initial_total + int(e.births) - int(e.deaths), "Population conservation holds through two days at capacity.")

func _run() -> void:
	test_directory = "res://build/tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_contracts()
	_audit_regressions()
	_environment()
	_environment_access()
	_environment_migrations()
	_map_and_travel()
	_clock_and_scheduler()
	_actions()
	_random_and_replay()
	_save_files()
	_session_lifecycle()
	await _ui()
	print("Simulation checks: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)
