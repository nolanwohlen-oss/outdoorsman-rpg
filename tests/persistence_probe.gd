extends SceneTree
## Called in two independent OS processes, never sharing an in-memory world.

const Kernel = preload("res://simulation/kernel.gd")
const SaveStore = preload("res://simulation/save_store.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0] in ["write", "read"]:
		push_error("Expected write|read and an isolated save directory.")
		quit(1)
		return
	var store := SaveStore.new(args[1])
	var k := Kernel.new(42)
	if args[0] == "write":
		k.move("elevated_camp")
		for hour in 24:
			k.wait_minutes(60)
		k.advance_real_us(1)
		k.random_u31()
		k.schedule_marker(300000, "after restart")
		var result := store.save_slot("manual", k.world.to_record())
		if not result.ok:
			push_error(result.message)
			quit(1)
			return
		# Persist independent expected current and future fingerprints for comparison.
		var current := SaveStore.fingerprint(k.world.to_record())
		k.random_u31()
		k.wait_minutes(15)
		var expected := {"current": current, "future": SaveStore.fingerprint(k.world.to_record())}
		store._write(args[1].path_join("expected.json"), JSON.stringify(expected))
		print("Cross-process checkpoint written after one simulated day.")
	else:
		var result := store.load_slot("manual")
		if not result.ok or not k.restore(result.record).ok:
			push_error("Independent process failed to load the checkpoint.")
			quit(1)
			return
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1].path_join("expected.json")))
		if SaveStore.fingerprint(k.world.to_record()) != expected.current or k.world.game_time_ms != 108120000:
			push_error("Independent process changed the saved world or granted offline time.")
			quit(1)
			return
		k.random_u31()
		k.wait_minutes(15)
		if SaveStore.fingerprint(k.world.to_record()) != expected.future:
			push_error("Independent process diverged after resuming the saved world.")
			quit(1)
			return
		print("Cross-process reload and future replay: passed.")
	quit(0)
