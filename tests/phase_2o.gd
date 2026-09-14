extends SceneTree

const Kernel = preload("res://simulation/kernel.gd")
const Inventory = preload("res://simulation/inventory.gd")
const World = preload("res://simulation/world_state.gd")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var k := Kernel.new(24680)
	var line_id := Inventory.carried_id(k.world.inventory, "test_line")
	var reel_id := Inventory.carried_id(k.world.inventory, "test_reel")
	if line_id.is_empty() or reel_id.is_empty():
		fail("2O: test tackle missing")
		return
	if not k.rig_fishing("lure").ok or Inventory.tackle_condition(k.world.inventory, line_id) != 1000 or Inventory.tackle_condition(k.world.inventory, reel_id) != 1000:
		fail("2O: rigging did not materialize pristine tackle condition")
		return
	if not k.cast_fishing().ok:
		fail("2O: cast failed")
		return
	k.advance_game_ms(120000)
	if not k.hook_fishing().ok:
		fail("2O: hook failed")
		return
	var cue: String = k.world.fishing.fish_cue
	var action := "give_line" if cue == "surge" else ("pressure" if cue == "pull" else "reel")
	var fought := k.fight_fishing(action)
	if not fought.ok:
		fail("2O: fight action failed: " + fought.message)
		return
	var line_after := Inventory.tackle_condition(k.world.inventory, line_id)
	var reel_after := Inventory.tackle_condition(k.world.inventory, reel_id)
	if line_after >= 1000 or reel_after >= 1000 or line_after < 0 or reel_after < 0:
		fail("2O: deterministic fight wear was not applied")
		return
	if k.world.fishing.state != "idle":
		k.cancel_fishing()
	var moved := k.move_plan("elevated_camp")
	if not moved.ok:
		fail("2O: could not reach camp for recovery: " + moved.message)
		return
	var before_service := Inventory.tackle_condition(k.world.inventory, line_id)
	var serviced := k.service_tackle(line_id)
	if not serviced.ok or Inventory.tackle_condition(k.world.inventory, line_id) <= before_service or not k.world.inventory.entries.has(line_id):
		fail("2O: service did not preserve identity and restore condition")
		return
	var replaced := k.replace_tackle(reel_id)
	var new_reel_id := Inventory.carried_id(k.world.inventory, "test_reel")
	if not replaced.ok or new_reel_id == reel_id or k.world.inventory.entries.has(reel_id) or Inventory.tackle_condition(k.world.inventory, new_reel_id) != 1000:
		fail("2O: replacement did not create a fresh full-condition identity")
		return
	var errors := World.validate(k.world.to_record())
	if not errors.is_empty():
		fail("2O: final world validation failed: " + " ".join(errors))
		return
	print("Phase 2O tackle wear/service/replacement invariants: passed.")
	quit(0)
