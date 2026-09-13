extends SceneTree
## Behavioral gates: conservation of time, replay, persistence, and lifecycle.

const Catalog = preload("res://scripts/catalog.gd")
const World = preload("res://simulation/world_state.gd")
const Kernel = preload("res://simulation/kernel.gd")
const Session = preload("res://simulation/session.gd")
const SaveStore = preload("res://simulation/save_store.gd")
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
	bad.player.zone_id = "open_water"
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.random_stream.state = 0
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.seed = true
	mutations.append(bad)
	bad = record.duplicate(true)
	bad.schema_version = 2
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
	check(app.tabs.get_tab_count() == 4 and app.zone_buttons.size() == 6, "Clock, Map, Layers, Log and six zones launch.")
	var initial = app.kernel.world.to_record()
	for zone in catalog.zones:
		app.zone_buttons[zone.id].pressed.emit()
		check(app.selected_zone_id == zone.id and app.inspector_title.text == zone.name, "Every zone is inspectable by touch.")
	check(app.kernel.world.to_record() == initial, "Map inspection cannot move the player or advance simulation.")
	check(app.wait_buttons[0].disabled, "Unsafe waiting is disabled at shore.")
	app._move_to("elevated_camp")
	check(not app.wait_buttons[0].disabled, "Camp enables the safe wait controls.")
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
	app.queue_free()
	await process_frame

func _run() -> void:
	test_directory = "res://build/tests-%d" % OS.get_process_id()
	_contracts()
	_clock_and_scheduler()
	_actions()
	_random_and_replay()
	_save_files()
	_session_lifecycle()
	await _ui()
	print("Phase 2A checks: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)
