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

func hooked_fixture(seed: int) -> Kernel:
	var k := Kernel.new(seed)
	if not k.rig_fishing("lure").ok or not k.cast_fishing().ok:
		return k
	k.advance_game_ms(Fishing.BITE_DELAY_MS)
	k.hook_fishing()
	return k

func correct_action(cue: String) -> String:
	return {"surge": "give_line", "pull": "pressure", "slack": "reel", "tired": "reel"}.get(cue, "")

func wrong_action(cue: String) -> String:
	return {"surge": "pressure", "pull": "give_line", "slack": "give_line", "tired": "give_line"}.get(cue, "pressure")

func finish_fight(k: Kernel) -> bool:
	for _round in 40:
		if Fishing.landing_ready(k.world.fishing):
			return true
		var result := k.fight_fishing(correct_action(String(k.world.fishing.fish_cue)))
		if not result.ok or result.status != "continue":
			return false
	return Fishing.landing_ready(k.world.fishing)

func _init() -> void:
	var k := Kernel.new(246813)
	if not Skills.validate(k.world.skills).is_empty() or not World.validate(k.world.to_record()).is_empty():
		fail("2Q: fresh skill/world record failed validation")
		return
	for id in Skills.SUBSKILLS:
		if xp(k, id) != 0 or Skills.subskill_level(k.world.skills, id) != 1:
			fail("2Q: fresh subskills must begin at Level 1 with zero XP")
			return
	if Skills.base_average(k.world.skills) != 1.0 or Skills.displayed_base_level(k.world.skills) != 1:
		fail("2Q: Angling base must derive from the four subskills")
		return

	var anchors := {1: 0, 10: 577, 25: 3921, 50: 50666, 75: 605210, 92: 3258626, 99: 6517215}
	for level in anchors:
		if Skills.threshold_for_level(int(level)) != int(anchors[level]):
			fail("2Q: canonical XP anchor changed at Level %d" % int(level))
			return
	var prior := -1
	for level in range(1, 100):
		var threshold := Skills.threshold_for_level(level)
		if threshold <= prior:
			fail("2Q: provisional threshold table is not strictly monotonic")
			return
		prior = threshold
	if Skills.level_for_xp(576) >= 10 or Skills.level_for_xp(577) != 10 or Skills.level_for_xp(Skills.MAX_XP) != 99:
		fail("2Q: threshold equality/cap behavior is incorrect")
		return

	var snapshot := k.world.to_record()
	if k.rig_fishing("invalid").ok or k.world.to_record() != snapshot or total_xp(k) != 0:
		fail("2Q: rejected actions must not award XP or mutate progression")
		return
	if not k.rig_fishing("lure").ok or total_xp(k) != 0:
		fail("2Q: preparing a rig alone must not farm XP")
		return
	if not k.cast_fishing().ok or xp(k, "tackle_rigging_bait_handling") != 5 or xp(k, "casting_presentation") != 0:
		fail("2Q: first physical use of a functional rig must award exactly its 5 XP pool")
		return
	if not k.cancel_fishing().ok or not k.rig_fishing("lure").ok or not k.cast_fishing().ok or xp(k, "tackle_rigging_bait_handling") != 5:
		fail("2Q: unchanged rig cancel/reassembly loop must not duplicate rig XP")
		return
	k.advance_game_ms(Fishing.BITE_DELAY_MS)
	if not k.hook_fishing().ok:
		fail("2Q: hook fixture failed")
		return
	if xp(k, "casting_presentation") != 1 or xp(k, "hooking_fighting_landing_release") != 3:
		fail("2Q: bite-confirmed cast and hookset must create separate canonical XP pools")
		return
	if xp(k, "fish_location_water_reading") != 0:
		fail("2Q: passive observation must not fabricate Fish Location XP")
		return

	var before_fight_xp := xp(k, "hooking_fighting_landing_release")
	var fight := k.fight_fishing(correct_action(String(k.world.fishing.fish_cue)))
	if not fight.ok or xp(k, "hooking_fighting_landing_release") != before_fight_xp + 1:
		fail("2Q: a correctly executed fight control must award exactly one base XP")
		return
	var encoded := JSON.stringify(k.world.to_record())
	var loaded := Kernel.new(1)
	if not loaded.restore(JSON.parse_string(encoded)).ok or loaded.world.skills != k.world.skills:
		fail("2Q: exact skill XP, levels-by-derivation and anti-exploit state must survive save/reload")
		return

	var wrong := hooked_fixture(13579)
	if wrong.world.fishing.state != "hooked":
		fail("2Q: wrong-action fixture failed")
		return
	var wrong_before := xp(wrong, "hooking_fighting_landing_release")
	var wrong_result := wrong.fight_fishing(wrong_action(String(wrong.world.fishing.fish_cue)))
	if not wrong_result.ok or xp(wrong, "hooking_fighting_landing_release") != wrong_before:
		fail("2Q: deliberate incorrect fight input must not create fight-control XP")
		return

	var landing := hooked_fixture(97531)
	if landing.world.fishing.state != "hooked" or not finish_fight(landing):
		fail("2Q: landing fixture could not reach a valid landing state")
		return
	var landing_before := xp(landing, "hooking_fighting_landing_release")
	if not landing.land_fishing(false, "net").ok or xp(landing, "hooking_fighting_landing_release") != landing_before + 10:
		fail("2Q: an ordinary completed landing must award exactly 10 base XP once")
		return

	var passive := Kernel.new(8642)
	var passive_before := total_xp(passive)
	passive.observe()
	passive.move_plan("elevated_camp")
	passive.wait_minutes(15)
	if total_xp(passive) != passive_before:
		fail("2Q: observation, travel and passive time must not create skill XP")
		return

	var legacy := Kernel.new(777).world.to_record()
	var legacy_time := int(legacy.clock.game_time_ms)
	legacy.erase("skills")
	legacy.schema_version = 14
	var migrated := World.migrate_record(legacy)
	if not migrated.ok or not migrated.migrated or int(migrated.record.schema_version) != World.SCHEMA_VERSION or int(migrated.record.clock.game_time_ms) != legacy_time:
		fail("2Q: schema 14 migration did not add progression without advancing time")
		return
	for id in Skills.SUBSKILLS:
		if int(migrated.record.skills.angling[id].xp) != 0:
			fail("2Q: migration must not invent retroactive XP")
			return

	var corrupt := k.world.to_record()
	corrupt.skills.angling.casting_presentation.xp = -1
	if World.validate(corrupt).is_empty():
		fail("2Q: invalid negative XP was accepted")
		return
	corrupt = k.world.to_record()
	corrupt.skills.rig_signatures.append(corrupt.skills.rig_signatures[0])
	if World.validate(corrupt).is_empty():
		fail("2Q: duplicate anti-exploit rig signature was accepted")
		return

	var saw_skill_log := false
	for entry in landing.world.history:
		if entry.kind == "skill_xp" and "source fishing_land_ordinary" in String(entry.detail):
			saw_skill_log = true
	if not saw_skill_log:
		fail("2Q: skill award log omitted the stable source action")
		return

	print("Phase 2Q Angling XP/persistence/anti-exploit invariants: passed.")
	quit(0)
