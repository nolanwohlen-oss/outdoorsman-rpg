extends SceneTree

const Kernel = preload("res://simulation/kernel.gd")
const Fishing = preload("res://simulation/fishing.gd")
const Skills = preload("res://simulation/skills.gd")
const World = preload("res://simulation/world_state.gd")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func xp(k: Kernel, id: String) -> int:
	return Skills.subskill_xp(k.world.skills, id)

func total_xp(k: Kernel) -> int:
	var total := 0
	for id in Skills.SUBSKILLS:
		total += xp(k, id)
	return total

func correct_action(cue: String) -> String:
	return {"surge": "give_line", "pull": "pressure", "slack": "reel", "tired": "reel"}.get(cue, "")

func wrong_action(cue: String) -> String:
	return {"surge": "pressure", "pull": "give_line", "slack": "give_line", "tired": "give_line"}.get(cue, "pressure")

func hooked_fixture(seed: int = 97531) -> Kernel:
	var k := Kernel.new(seed)
	if not k.rig_fishing("lure").ok or not k.cast_fishing("steady").ok:
		return k
	k.advance_game_ms(Fishing.BITE_DELAY_MS)
	var strike := k.check_fishing()
	if not strike.ok or strike.status != "strike":
		return k
	k.hook_fishing()
	return k

func finish_fight(k: Kernel) -> bool:
	for _round in 40:
		if Fishing.landing_ready(k.world.fishing):
			return true
		var result := k.fight_fishing(correct_action(String(k.world.fishing.fish_cue)))
		if not result.ok or result.status != "continue":
			return false
	return Fishing.landing_ready(k.world.fishing)

func _init() -> void:
	var k := Kernel.new(97531)
	if not Skills.validate(k.world.skills).is_empty() or not World.validate(k.world.to_record()).is_empty():
		fail("2R: fresh progression/world record failed validation")
		return
	for id in Skills.SUBSKILLS:
		if xp(k, id) != 0 or Skills.subskill_level(k.world.skills, id) != 1:
			fail("2R: fresh Angling subskills must begin at Level 1 with zero XP")
			return
	if Skills.base_average(k.world.skills) != 1.0 or Skills.displayed_base_level(k.world.skills) != 1:
		fail("2R: Angling base must derive only from its four subskill levels")
		return

	var anchors := {1: 0, 10: 577, 25: 3921, 50: 50666, 75: 605210, 92: 3258626, 99: 6517215}
	for level in anchors:
		if Skills.threshold_for_level(int(level)) != int(anchors[level]):
			fail("2R: canonical XP anchor changed at Level %d" % int(level))
			return
	var previous := -1
	for level in range(1, 100):
		var threshold := Skills.threshold_for_level(level)
		if threshold <= previous:
			fail("2R: provisional threshold table is not strictly monotonic")
			return
		previous = threshold
	if Skills.level_for_xp(576) >= 10 or Skills.level_for_xp(577) != 10 or Skills.level_for_xp(Skills.MAX_XP) != 99:
		fail("2R: threshold equality or Level-99 cap behavior is incorrect")
		return

	var snapshot := k.world.to_record()
	if k.rig_fishing("invalid").ok or k.world.to_record() != snapshot or total_xp(k) != 0:
		fail("2R: rejected actions must not award XP or mutate progression")
		return
	if not k.rig_fishing("lure").ok or total_xp(k) != 0:
		fail("2R: preparing a rig alone must not award XP")
		return
	if not k.cast_fishing("steady").ok or xp(k, "tackle_rigging_bait_handling") != 5 or xp(k, "casting_presentation") != 0 or not bool(k.world.skills.cast_xp_pending):
		fail("2R: first functional rig deployment must award rig XP and arm, not prematurely award, cast XP")
		return
	if not k.cancel_fishing().ok or bool(k.world.skills.cast_xp_pending) or xp(k, "casting_presentation") != 0:
		fail("2R: cancelling before the first due presentation check must clear pending cast XP without awarding it")
		return
	if not k.rig_fishing("lure").ok or not k.cast_fishing("steady").ok or xp(k, "tackle_rigging_bait_handling") != 5:
		fail("2R: unchanged rig reassembly/deployment must not duplicate functional-rig XP")
		return
	k.advance_game_ms(Fishing.BITE_DELAY_MS)
	var strike := k.check_fishing()
	if not strike.ok or strike.status != "strike":
		fail("2R: deterministic 2Q strike fixture no longer produces a strike")
		return
	if xp(k, "casting_presentation") != 1 or xp(k, "fish_location_water_reading") != 2 or bool(k.world.skills.cast_xp_pending):
		fail("2R: first due presentation completion and strike interpretation did not route separate XP pools correctly")
		return
	var after_strike_xp := total_xp(k)
	if not k.check_fishing().ok or total_xp(k) != after_strike_xp:
		fail("2R: rereading an unchanged strike state duplicated XP")
		return
	if not k.hook_fishing().ok or xp(k, "hooking_fighting_landing_release") != 3:
		fail("2R: successful hookset must award exactly 3 base XP")
		return
	var fight_before := xp(k, "hooking_fighting_landing_release")
	var fight := k.fight_fishing(correct_action(String(k.world.fishing.fish_cue)))
	if not fight.ok or xp(k, "hooking_fighting_landing_release") != fight_before + 1:
		fail("2R: correctly interpreted fight control must award exactly one base XP")
		return
	var encoded := JSON.stringify(k.world.to_record())
	var loaded := Kernel.new(1)
	if not loaded.restore(JSON.parse_string(encoded)).ok or loaded.world.skills != k.world.skills:
		fail("2R: exact Angling XP and anti-exploit state did not survive JSON save/reload")
		return

	var wrong := hooked_fixture(97531)
	if wrong.world.fishing.state != "hooked":
		fail("2R: wrong-fight-action fixture failed")
		return
	var wrong_before := xp(wrong, "hooking_fighting_landing_release")
	var wrong_result := wrong.fight_fishing(wrong_action(String(wrong.world.fishing.fish_cue)))
	if not wrong_result.ok or xp(wrong, "hooking_fighting_landing_release") != wrong_before:
		fail("2R: deliberately incorrect fight input created fight-control XP")
		return

	var landing := hooked_fixture(97531)
	if landing.world.fishing.state != "hooked" or not finish_fight(landing):
		fail("2R: landing fixture could not reach a valid landing state")
		return
	var landing_before := xp(landing, "hooking_fighting_landing_release")
	if not landing.land_fishing(false, "net").ok or xp(landing, "hooking_fighting_landing_release") != landing_before + 10:
		fail("2R: completed ordinary landing did not award exactly 10 base XP")
		return

	var empty := Kernel.new(86420)
	var zone: String = empty.world.player_zone
	for species in Fishing.SPECIES:
		empty.world.ecology.populations[species][zone] = 0
	if not empty.rig_fishing("lure").ok or not empty.cast_fishing("steady").ok:
		fail("2R: zero-population purposeful-cast fixture failed")
		return
	empty.advance_game_ms(Fishing.BITE_DELAY_MS)
	var no_strike := empty.check_fishing()
	if not no_strike.ok or no_strike.status != "no_strike" or xp(empty, "casting_presentation") != 1 or xp(empty, "fish_location_water_reading") != 0:
		fail("2R: completed purposeful cast without a strike should earn cast XP without fabricating strike-reading XP")
		return
	var empty_total := total_xp(empty)
	empty.advance_game_ms(Fishing.BITE_DELAY_MS)
	if not empty.check_fishing().ok or total_xp(empty) != empty_total:
		fail("2R: repeated checks on the same no-strike cast farmed XP")
		return

	var passive := Kernel.new(8642)
	var passive_before := total_xp(passive)
	passive.observe()
	passive.move_plan("elevated_camp")
	passive.wait_minutes(15)
	if total_xp(passive) != passive_before:
		fail("2R: observation, travel or passive time created Angling XP")
		return

	var legacy := Kernel.new(777).world.to_record()
	var legacy_time := int(legacy.clock.game_time_ms)
	legacy.erase("skills")
	legacy.schema_version = 15
	var migrated := World.migrate_record(legacy)
	if not migrated.ok or not migrated.migrated or int(migrated.record.schema_version) != World.SCHEMA_VERSION or int(migrated.record.clock.game_time_ms) != legacy_time:
		fail("2R: Phase 2Q schema-15 save did not gain progression without advancing game time")
		return
	for id in Skills.SUBSKILLS:
		if int(migrated.record.skills.angling[id].xp) != 0:
			fail("2R: migration invented retroactive skill XP")
			return

	var corrupt := k.world.to_record()
	corrupt.skills.angling.casting_presentation.xp = -1
	if World.validate(corrupt).is_empty():
		fail("2R: current validation accepted negative XP")
		return
	corrupt = k.world.to_record()
	corrupt.skills.rig_signatures.append(corrupt.skills.rig_signatures[0])
	if World.validate(corrupt).is_empty():
		fail("2R: duplicate functional-rig XP guard was accepted")
		return
	corrupt = Kernel.new(42).world.to_record()
	corrupt.skills.cast_xp_pending = true
	if World.validate(corrupt).is_empty():
		fail("2R: idle world accepted an impossible pending cast-XP completion")
		return

	var cap_record := Skills.create()
	cap_record.angling.hooking_fighting_landing_release.xp = Skills.MAX_XP - 5
	var cap_award := Skills.award(cap_record, "fishing_land_ordinary")
	if not cap_award.ok or int(cap_record.angling.hooking_fighting_landing_release.xp) != Skills.MAX_XP or Skills.subskill_level(cap_record, "hooking_fighting_landing_release") != 99:
		fail("2R: XP overflow was not clamped at canonical Level-99 mastery")
		return

	var saw_skill_log := false
	for entry in landing.world.history:
		if entry.kind == "skill_xp" and "source fishing_land_ordinary" in String(entry.detail):
			saw_skill_log = true
	if not saw_skill_log:
		fail("2R: skill award audit log omitted its stable action ID")
		return

	print("Phase 2R Angling progression/persistence/anti-exploit invariants: passed.")
	quit(0)
