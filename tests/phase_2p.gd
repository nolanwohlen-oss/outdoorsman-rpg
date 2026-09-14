extends SceneTree

const Kernel = preload("res://simulation/kernel.gd")
const Inventory = preload("res://simulation/inventory.gd")
const Fishing = preload("res://simulation/fishing.gd")
const World = preload("res://simulation/world_state.gd")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func hooked_fixture(seed: int) -> Kernel:
	var k := Kernel.new(seed)
	if not k.rig_fishing("lure").ok or not k.cast_fishing().ok:
		return k
	k.advance_game_ms(Fishing.BITE_DELAY_MS)
	k.hook_fishing()
	return k

func last_history_detail(k: Kernel) -> String:
	if k.world.history.is_empty():
		return ""
	return String(k.world.history[-1].detail)

func _init() -> void:
	var k := hooked_fixture(86420)
	if k.world.fishing.state != "hooked":
		fail("2P: hooked fixture failed")
		return
	var ids := [k.world.fishing.rod_item_id, k.world.fishing.reel_item_id, k.world.fishing.line_item_id, k.world.fishing.terminal_item_id]
	for id in ids:
		if Inventory.tackle_condition(k.world.inventory, id) != 1000:
			fail("2P: full rig condition was not materialized")
			return

	var base_record := k.world.to_record()
	base_record.fishing.fish_cue = "pull"
	base_record.fishing.line_tension = 500
	var loose := Kernel.new(1)
	var tight := Kernel.new(1)
	if not loose.restore(base_record).ok or not tight.restore(base_record).ok:
		fail("2P: drag comparison restore failed")
		return
	var loose_result := loose.fight_fishing("pressure", "loose")
	var tight_result := tight.fight_fishing("pressure", "tight")
	if not loose_result.ok or not tight_result.ok or loose.world.fishing.state != "hooked" or tight.world.fishing.state != "hooked" or int(tight.world.fishing.line_tension) <= int(loose.world.fishing.line_tension):
		fail("2P: tight drag did not create higher line tension from the same state")
		return

	var worn := Kernel.new(2)
	if not worn.restore(base_record).ok:
		fail("2P: worn-line restore failed")
		return
	var worn_line: String = worn.world.fishing.line_item_id
	worn.world.inventory.entries[worn_line].condition = 100
	var worn_result := worn.fight_fishing("pressure", "tight")
	var worn_log := last_history_detail(worn)
	if not worn_result.ok or worn_result.status != "overload" or Inventory.tackle_condition(worn.world.inventory, worn_line) != 0:
		fail("2P: worn line strength did not cause an auditable overload")
		return
	if "tight drag" not in worn_log or "rod " not in worn_log or "reel " not in worn_log or "line 0" not in worn_log or "terminal " not in worn_log:
		fail("2P: failed fight log omitted drag or final rig condition")
		return
	var broken_snapshot := worn.world.to_record()
	if worn.rig_fishing("lure").ok or worn.world.to_record() != broken_snapshot:
		fail("2P: broken line did not reject a new rig atomically")
		return

	var weakest := Kernel.new(3)
	if not weakest.restore(base_record).ok:
		fail("2P: weakest-link restore failed")
		return
	var weak_line: String = weakest.world.fishing.line_item_id
	var weak_terminal: String = weakest.world.fishing.terminal_item_id
	weakest.world.inventory.entries[weak_line].condition = 100
	weakest.world.inventory.entries[weak_terminal].condition = 1
	var weakest_result := weakest.fight_fishing("pressure", "tight")
	if not weakest_result.ok or weakest_result.status != "tackle_failure" or Inventory.tackle_condition(weakest.world.inventory, weak_terminal) != 0 or Inventory.tackle_condition(weakest.world.inventory, weak_line) <= 0:
		fail("2P: lowest terminal limit did not own a simultaneous overload")
		return

	var rejected := Kernel.new(4)
	for id in rejected.world.inventory.entries:
		if rejected.world.inventory.entries[id].kind in Inventory.TRACKED_TACKLE:
			rejected.world.inventory.entries[id].condition = -1
	if not World.validate(rejected.world.to_record()).is_empty():
		fail("2P: legacy-sentinel fixture is invalid")
		return
	var rejected_snapshot := rejected.world.to_record()
	if rejected.rig_fishing("bait", "").ok or rejected.world.to_record() != rejected_snapshot:
		fail("2P: rejected bait rig materialized legacy tackle condition")
		return

	var normal := hooked_fixture(86421)
	var cue: String = normal.world.fishing.fish_cue
	var action := "give_line" if cue == "surge" else ("pressure" if cue == "pull" else "reel")
	var rod_id: String = normal.world.fishing.rod_item_id
	var reel_id: String = normal.world.fishing.reel_item_id
	var line_id: String = normal.world.fishing.line_item_id
	var term_id: String = normal.world.fishing.terminal_item_id
	var result := normal.fight_fishing(action, "balanced")
	if not result.ok:
		fail("2P: normal fight action failed: " + result.message)
		return
	var expected_conditions := {}
	for id in [rod_id, reel_id, line_id, term_id]:
		var condition := Inventory.tackle_condition(normal.world.inventory, id)
		if condition >= 1000:
			fail("2P: fight did not wear every linked rig component")
			return
		expected_conditions[id] = condition
	var reloaded := Kernel.new(5)
	var json_record: Dictionary = JSON.parse_string(JSON.stringify(normal.world.to_record()))
	if not reloaded.restore(json_record).ok:
		fail("2P: worn-rig save/reload failed")
		return
	for id in expected_conditions:
		if Inventory.tackle_condition(reloaded.world.inventory, id) != int(expected_conditions[id]):
			fail("2P: exact rig condition changed across save/reload")
			return

	if normal.world.fishing.state != "idle":
		normal.cancel_fishing()
	var moved := normal.move_plan("elevated_camp")
	if not moved.ok:
		fail("2P: could not reach camp")
		return
	var before := Inventory.tackle_condition(normal.world.inventory, rod_id)
	var serviced := normal.service_tackle(rod_id)
	if not serviced.ok or not normal.world.inventory.entries.has(rod_id) or Inventory.tackle_condition(normal.world.inventory, rod_id) <= before:
		fail("2P: rod service did not preserve identity and restore condition")
		return
	var replacement_old := reel_id
	var replaced := normal.replace_tackle(replacement_old)
	var replacement_new := Inventory.carried_id(normal.world.inventory, "test_reel")
	if not replaced.ok or normal.world.inventory.entries.has(replacement_old) or replacement_new == replacement_old or replacement_new.is_empty() or Inventory.tackle_condition(normal.world.inventory, replacement_new) != 1000:
		fail("2P: replacement did not create a new full-condition physical identity")
		return
	var final_reload := Kernel.new(6)
	if not final_reload.restore(JSON.parse_string(JSON.stringify(normal.world.to_record()))).ok or Inventory.carried_id(final_reload.world.inventory, "test_reel") != replacement_new:
		fail("2P: replacement identity did not persist through save/reload")
		return
	var errors := World.validate(final_reload.world.to_record())
	if not errors.is_empty():
		fail("2P: final world validation failed: " + " ".join(errors))
		return
	print("Phase 2P full-audit rig causality invariants: passed.")
	quit(0)
