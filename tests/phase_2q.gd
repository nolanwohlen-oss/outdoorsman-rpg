extends SceneTree

const Kernel = preload("res://simulation/kernel.gd")
const Fishing = preload("res://simulation/fishing.gd")
const World = preload("res://simulation/world_state.gd")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func last_history_detail(k: Kernel) -> String:
	if k.world.history.is_empty():
		return ""
	return String(k.world.history[-1].detail)

func _init() -> void:
	var k := Kernel.new(97531)
	if not k.rig_fishing("lure").ok:
		fail("2Q: lure rig failed")
		return
	var pre_cast := k.world.to_record()
	if k.cast_fishing("soak").ok or k.world.to_record() != pre_cast:
		fail("2Q: incompatible lure presentation was not rejected atomically")
		return
	if not k.cast_fishing("steady").ok or k.world.fishing.state != "cast" or k.world.fishing.presentation != "steady" or not k.world.fishing.target_species.is_empty() or not k.world.fishing.strike_cue.is_empty():
		fail("2Q: cast selected a species or failed to persist presentation")
		return
	var cast_snapshot := k.world.to_record()
	if k.check_fishing().ok or k.world.to_record() != cast_snapshot:
		fail("2Q: early strike check mutated the world")
		return
	var waiting_reload := Kernel.new(1)
	if not waiting_reload.restore(JSON.parse_string(JSON.stringify(cast_snapshot))).ok or waiting_reload.world.fishing.presentation != "steady" or not waiting_reload.world.fishing.target_species.is_empty():
		fail("2Q: waiting presentation did not survive save/reload")
		return
	var rng_before := k.world.rng_state
	k.advance_game_ms(Fishing.BITE_DELAY_MS)
	var strike := k.check_fishing()
	if not strike.ok or strike.status != "strike" or k.world.fishing.target_species.is_empty() or k.world.fishing.strike_cue not in Fishing.STRIKE_CUES or k.world.rng_state != rng_before:
		fail("2Q: deterministic strike causality failed on the default fixture")
		return
	var hidden_species: String = k.world.fishing.target_species
	if hidden_species in String(strike.message) or hidden_species in last_history_detail(k):
		fail("2Q: strike feedback leaked premature species certainty")
		return
	var strike_reload := Kernel.new(2)
	if not strike_reload.restore(JSON.parse_string(JSON.stringify(k.world.to_record()))).ok or strike_reload.world.fishing.target_species != hidden_species or strike_reload.world.fishing.strike_cue != k.world.fishing.strike_cue:
		fail("2Q: engaged strike did not survive save/reload exactly")
		return
	if not k.hook_fishing().ok or k.world.fishing.state != "hooked" or k.world.fishing.target_species != hidden_species:
		fail("2Q: hook did not reveal and preserve the engaged species")
		return

	var empty := Kernel.new(86420)
	var zone: String = empty.world.player_zone
	for species in Fishing.SPECIES:
		empty.world.ecology.populations[species][zone] = 0
	if not World.validate(empty.world.to_record()).is_empty():
		fail("2Q: zero-local-population fixture is invalid")
		return
	if not empty.rig_fishing("lure").ok or not empty.cast_fishing("steady").ok:
		fail("2Q: physically valid cast was blocked merely because no fish were present")
		return
	empty.advance_game_ms(Fishing.BITE_DELAY_MS)
	var empty_rng := empty.world.rng_state
	var first_due := int(empty.world.fishing.bite_due_ms)
	var no_strike := empty.check_fishing()
	if not no_strike.ok or no_strike.status != "no_strike" or not empty.world.fishing.target_species.is_empty() or not empty.world.fishing.strike_cue.is_empty() or empty.world.rng_state != empty_rng or int(empty.world.fishing.bite_due_ms) != first_due + Fishing.BITE_DELAY_MS:
		fail("2Q: fish absence did not produce a deterministic no-strike continuation")
		return

	var water: Dictionary = k.world.environment.water_by_zone[zone].duplicate(true)
	var populations: Dictionary = {}
	for species in Fishing.SPECIES:
		populations[species] = {zone: 0}
	populations.redfish[zone] = 3
	var good_score := Fishing.engagement_score("redfish", "lure", "steady", water, 3)
	water.oxygen_centi_mg_l = 300
	var low_oxygen_score := Fishing.engagement_score("redfish", "lure", "steady", water, 3)
	if low_oxygen_score >= good_score:
		fail("2Q: water oxygen did not causally reduce engagement suitability")
		return
	var drift_score := Fishing.engagement_score("redfish", "lure", "drift", k.world.environment.water_by_zone[zone], 3)
	if drift_score == good_score:
		fail("2Q: presentation choice did not causally affect engagement suitability")
		return

	var legacy_source := Kernel.new(24680)
	if not legacy_source.rig_fishing("lure").ok or not legacy_source.cast_fishing("steady").ok:
		fail("2Q: legacy migration fixture setup failed")
		return
	var legacy := legacy_source.world.to_record()
	legacy.schema_version = 14
	legacy.fishing.version = 5
	legacy.fishing.erase("strike_started_ms")
	legacy.fishing.erase("hook_placement")
	legacy.fishing.erase("hook_hold")
	legacy.fishing.erase("hook_injury")
	legacy.fishing.erase("presentation")
	legacy.fishing.erase("strike_cue")
	legacy.fishing.target_species = "redfish"
	var legacy_time := int(legacy.clock.game_time_ms)
	var migrated := World.migrate_record(legacy)
	if not migrated.ok or not migrated.migrated or int(migrated.record.schema_version) != World.SCHEMA_VERSION or int(migrated.record.clock.game_time_ms) != legacy_time or migrated.record.fishing.presentation != "steady" or migrated.record.fishing.strike_cue != Fishing.strike_cue_for("redfish", "steady"):
		fail("2Q: Phase 2P save did not migrate without hidden time advancement")
		return

	var corrupt: Dictionary = migrated.record.duplicate(true)
	corrupt.fishing.presentation = "soak"
	if World.validate(corrupt).is_empty():
		fail("2Q: current save validation accepted an incompatible active presentation")
		return
	print("Phase 2Q presentation/strike causality invariants: passed.")
	quit(0)
