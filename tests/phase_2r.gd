extends SceneTree

const Kernel = preload("res://simulation/kernel.gd")
const Fishing = preload("res://simulation/fishing.gd")
const Inventory = preload("res://simulation/inventory.gd")
const World = preload("res://simulation/world_state.gd")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func last_detail(k: Kernel) -> String:
	return "" if k.world.history.is_empty() else String(k.world.history[-1].detail)

func correct_action(cue: String) -> String:
	return {"surge": "give_line", "pull": "pressure", "slack": "reel", "tired": "reel"}.get(cue, "")

func finish_fight(k: Kernel) -> bool:
	for _round in 40:
		if Fishing.landing_ready(k.world.fishing):
			return true
		var action := correct_action(String(k.world.fishing.fish_cue))
		var result := k.fight_fishing(action, "balanced")
		if not result.ok or result.status != "continue":
			return false
	return Fishing.landing_ready(k.world.fishing)

func strike_fixture(seed: int = 97531) -> Kernel:
	var k := Kernel.new(seed)
	if not k.rig_fishing("lure").ok or not k.cast_fishing("steady").ok:
		return k
	k.advance_game_ms(Fishing.BITE_DELAY_MS)
	k.check_fishing()
	return k

func _init() -> void:
	# Pure hook-set table: timing and force must matter deterministically.
	var tap_firm := Fishing.hookset_result("tap", "firm", 0)
	var tap_hard := Fishing.hookset_result("tap", "hard", 0)
	var run_soft := Fishing.hookset_result("run", "soft", 0)
	var expired := Fishing.hookset_result("pull", "firm", Fishing.HOOK_RESPONSE_WINDOW_MS + 1)
	if not tap_firm.ok or tap_firm.status != "hooked" or tap_firm.placement != "corner":
		fail("2R: immediate firm tap did not resolve to the expected secure placement")
		return
	if not tap_hard.ok or tap_hard.status != "hooked" or int(tap_hard.injury) <= int(tap_firm.injury):
		fail("2R: hard hook set did not increase tissue injury")
		return
	if not run_soft.ok or run_soft.status != "missed":
		fail("2R: premature soft response to a run cue should fail to establish a hold")
		return
	if not expired.ok or expired.status != "missed":
		fail("2R: expired response window did not miss the fish")
		return

	var base := strike_fixture()
	if base.world.fishing.state != "cast" or base.world.fishing.target_species.is_empty() or base.world.fishing.strike_cue not in Fishing.STRIKE_CUES or int(base.world.fishing.strike_started_ms) != base.world.game_time_ms:
		fail("2R: strike detection did not start an exact Game Clock response window")
		return
	var pre_hook := base.world.to_record()
	var hidden_species := String(base.world.fishing.target_species)
	var strike_time := int(base.world.fishing.strike_started_ms)

	var firm := Kernel.new(1)
	var hard := Kernel.new(2)
	if not firm.restore(pre_hook).ok or not hard.restore(pre_hook).ok:
		fail("2R: pre-hook state could not be replayed")
		return
	var firm_result := firm.hook_fishing("firm")
	var hard_result := hard.hook_fishing("hard")
	if not firm_result.ok or firm_result.status != "hooked" or firm.world.fishing.state != "hooked" or firm.world.fishing.target_species != hidden_species:
		fail("2R: firm hook set did not reveal and preserve the engaged species")
		return
	if firm.world.fishing.hook_placement not in Fishing.HOOK_PLACEMENTS or int(firm.world.fishing.hook_hold) <= 0 or int(firm.world.fishing.hook_injury) <= 0:
		fail("2R: successful hook set did not create persistent placement/hold/injury state")
		return
	if not hard_result.ok or hard_result.status != "hooked" or hard.world.fishing.hook_placement == firm.world.fishing.hook_placement or int(hard.world.fishing.hook_injury) <= int(firm.world.fishing.hook_injury):
		fail("2R: hook-force choice did not causally change placement/injury from the same strike")
		return

	var reloaded := Kernel.new(3)
	if not reloaded.restore(JSON.parse_string(JSON.stringify(firm.world.to_record()))).ok or reloaded.world.fishing.hook_placement != firm.world.fishing.hook_placement or reloaded.world.fishing.hook_hold != firm.world.fishing.hook_hold or reloaded.world.fishing.hook_injury != firm.world.fishing.hook_injury or reloaded.world.fishing.strike_started_ms != strike_time:
		fail("2R: active hook state did not survive JSON save/reload exactly")
		return

	var late := Kernel.new(4)
	late.restore(pre_hook)
	late.advance_game_ms(Fishing.HOOK_RESPONSE_WINDOW_MS + 1)
	var late_result := late.hook_fishing("firm")
	if not late_result.ok or late_result.status != "missed" or late.world.fishing.state != "idle" or hidden_species in String(late_result.message) or hidden_species in last_detail(late):
		fail("2R: expired hook response did not close cleanly while preserving pre-hook species uncertainty")
		return

	# Hook state is now a third physical connection in the fight. Make it clearly
	# weaker than pristine line/terminal tackle and force an overload.
	var weak := Kernel.new(5)
	weak.restore(firm.world.to_record())
	weak.world.fishing.hook_hold = 300
	weak.world.fishing.hook_injury = 600
	if not World.validate(weak.world.to_record()).is_empty():
		fail("2R: weak-but-valid hook fixture failed validation")
		return
	var line_id := String(weak.world.fishing.line_item_id)
	var terminal_id := String(weak.world.fishing.terminal_item_id)
	var line_before := Inventory.tackle_condition(weak.world.inventory, line_id)
	var terminal_before := Inventory.tackle_condition(weak.world.inventory, terminal_id)
	var weak_result := weak.fight_fishing("pressure", "tight")
	if not weak_result.ok or weak_result.status != "hook_pull" or weak.world.fishing.state != "idle":
		fail("2R: weak hook did not own the overload failure")
		return
	if Inventory.tackle_condition(weak.world.inventory, line_id) <= 0 or Inventory.tackle_condition(weak.world.inventory, terminal_id) <= 0 or line_before <= 0 or terminal_before <= 0:
		fail("2R: hook-pull failure falsely broke intact line or terminal tackle")
		return

	# Hook injury must survive into landing consequence rather than disappearing.
	var ready := Kernel.new(6)
	ready.restore(firm.world.to_record())
	if not finish_fight(ready):
		fail("2R: normal firm-hook fixture could not reach landing range")
		return
	var low_record := ready.world.to_record()
	var high_record := ready.world.to_record()
	high_record.fishing.hook_injury = 800
	var low := Kernel.new(7)
	var high := Kernel.new(8)
	if not low.restore(low_record).ok or not high.restore(high_record).ok:
		fail("2R: landing injury comparison fixtures failed validation")
		return
	if not low.land_fishing(false, "net").ok or not high.land_fishing(false, "net").ok:
		fail("2R: injury comparison landing failed")
		return
	if int(high.world.fishing.last_handling_condition) >= int(low.world.fishing.last_handling_condition):
		fail("2R: greater hook injury did not reduce release handling condition")
		return

	# Schema-15 Phase 2Q active fights migrate without offline time and receive a
	# deterministic neutral legacy hook state.
	var legacy := firm.world.to_record()
	var legacy_time := int(legacy.clock.game_time_ms)
	legacy.schema_version = 15
	legacy.fishing.version = 6
	legacy.fishing.erase("strike_started_ms")
	legacy.fishing.erase("hook_placement")
	legacy.fishing.erase("hook_hold")
	legacy.fishing.erase("hook_injury")
	var migrated := World.migrate_record(legacy)
	if not migrated.ok or not migrated.migrated or int(migrated.record.schema_version) != World.SCHEMA_VERSION or int(migrated.record.clock.game_time_ms) != legacy_time:
		fail("2R: Phase 2Q save migration changed time or failed")
		return
	if migrated.record.fishing.state != "hooked" or migrated.record.fishing.hook_placement != "jaw" or int(migrated.record.fishing.hook_hold) != 850 or int(migrated.record.fishing.hook_injury) != 120:
		fail("2R: active Phase 2Q fight was not preserved with neutral legacy hook state")
		return

	var corrupt := firm.world.to_record()
	corrupt.fishing.hook_placement = ""
	if World.validate(corrupt).is_empty():
		fail("2R: current validation accepted a hooked fish without placement")
		return
	corrupt = pre_hook.duplicate(true)
	corrupt.fishing.strike_started_ms = 0
	if World.validate(corrupt).is_empty():
		fail("2R: current validation accepted a detected strike without response time")
		return

	print("Phase 2R strike-response/hook-set causality invariants: passed.")
	quit(0)
