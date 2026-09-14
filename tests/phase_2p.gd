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
	if not loose_result.ok or not tight_result.ok:
		fail("2P: drag comparison action failed")
		return
	if loose.world.fishing.state == "hooked" and tight.world.fishing.state == "hooked" and int(tight.world.fishing.line_tension) <= int(loose.world.fishing.line_tension):
		fail("2P: tight drag did not create higher line tension")
		return

	var worn := Kernel.new(2)
	if not worn.restore(base_record).ok:
		fail("2P: worn-line restore failed")
		return
	var worn_line: String = worn.world.fishing.line_item_id
	worn.world.inventory.entries[worn_line].condition = 100
	var worn_result := worn.fight_fishing("pressure", "tight")
	if not worn_result.ok or worn_result.status != "overload" or Inventory.tackle_condition(worn.world.inventory, worn_line) != 0:
		fail("2P: worn line strength did not cause an auditable overload")
		return

	var terminal_case := Kernel.new(3)
	if not terminal_case.restore(base_record).ok:
		fail("2P: terminal-tackle restore failed")
		return
	var terminal_id: String = terminal_case.world.fishing.terminal_item_id
	terminal_case.world.inventory.entries[terminal_id].condition = 1
	var terminal_result := terminal_case.fight_fishing("pressure", "balanced")
	if not terminal_result.ok or terminal_result.status != "tackle_failure" or Inventory.tackle_condition(terminal_case.world.inventory, terminal_id) != 0:
		fail("2P: worn terminal tackle did not fail under load")
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
	for id in [rod_id, reel_id, line_id, term_id]:
		if Inventory.tackle_condition(normal.world.inventory, id) >= 1000:
			fail("2P: fight did not wear every linked rig component")
			return

	if normal.world.fishing.state != "idle":
		normal.cancel_fishing()
	var moved := normal.move_plan("elevated_camp")
	if not moved.ok:
		fail("2P: could not reach camp")
		return
	var before := Inventory.tackle_condition(normal.world.inventory, rod_id)
	var serviced := normal.service_tackle(rod_id)
	if not serviced.ok or Inventory.tackle_condition(normal.world.inventory, rod_id) <= before:
		fail("2P: rod service did not restore condition")
		return
	var errors := World.validate(normal.world.to_record())
	if not errors.is_empty():
		fail("2P: final world validation failed: " + " ".join(errors))
		return
	print("Phase 2P rig causality invariants: passed.")
	quit(0)
