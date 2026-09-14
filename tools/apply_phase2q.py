from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Phase 2Q anchor count for {path}: {count}; expected 1\n{old[:180]!r}")
    p.write_text(text.replace(old, new, 1))


def regex_once(path: str, pattern: str, replacement: str) -> None:
    p = ROOT / path
    text = p.read_text()
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"Phase 2Q regex anchor count for {path}: {count}; expected 1\n{pattern[:180]!r}")
    p.write_text(updated)


# --- fishing record + deterministic pre-hook causality ---
replace_once("simulation/fishing.gd", "const VERSION := 5", "const VERSION := 6")
replace_once(
    "simulation/fishing.gd",
    'const DRAG_SETTINGS := ["loose", "balanced", "tight"]\nconst FIGHT_CUES := ["surge", "pull", "slack", "tired"]',
    'const DRAG_SETTINGS := ["loose", "balanced", "tight"]\nconst PRESENTATIONS := ["steady", "drift", "soak"]\nconst STRIKE_CUES := ["tap", "pull", "run"]\nconst ENGAGEMENT_THRESHOLD := 65\nconst FIGHT_CUES := ["surge", "pull", "slack", "tired"]',
)
replace_once(
    "simulation/fishing.gd",
    '\t\t"rig_mode": "lure",\n\t\t"bait_item_id": "",',
    '\t\t"rig_mode": "lure",\n\t\t"presentation": "",\n\t\t"strike_cue": "",\n\t\t"bait_item_id": "",',
)

new_validate = r'''static func validate(record: Variant, now_ms: int, legacy: bool = false, old_v1: bool = false, old_v2: bool = false, old_v3: bool = false, old_v5: bool = false) -> PackedStringArray:
	var current_v6: bool = not legacy and not old_v1 and not old_v2 and not old_v3 and not old_v5
	var keys := ["version", "state", "zone", "target_species", "bite_due_ms", "last_outcome", "last_catch_weight_g", "retained_count", "released_count"]
	if not legacy and not old_v1:
		keys.append_array(["rig_mode", "bait_item_id"])
	if not legacy and not old_v1 and not old_v2:
		keys.append_array(["rod_item_id", "terminal_item_id"])
	if not legacy and not old_v1 and not old_v2 and not old_v3:
		keys.append_array(["reel_item_id", "line_item_id", "fish_stamina", "line_tension", "fish_distance_cm", "fight_round", "fish_cue", "lost_count"])
		keys.append_array(["last_handling_method", "last_handling_condition", "handling_count"])
	if current_v6:
		keys.append_array(["presentation", "strike_cue"])
	if legacy:
		keys = ["version", "state", "zone", "target_species", "bite_due_ms", "last_outcome"]
	var legacy_handling_fields: bool = (legacy or old_v1 or old_v2 or old_v3) and record is Dictionary and record.size() == keys.size() + 3 and record.has_all(["last_handling_method", "last_handling_condition", "handling_count"])
	if not record is Dictionary or (record.size() != keys.size() and not legacy_handling_fields) or not record.has_all(keys):
		return PackedStringArray(["Fishing state has missing or unknown fields."])
	if legacy:
		var expanded: Dictionary = record.duplicate(true)
		expanded.last_catch_weight_g = 0
		expanded.retained_count = 0
		expanded.released_count = 0
		return validate(expanded, now_ms, false, true)
	var numeric_fields := ["version", "bite_due_ms", "last_catch_weight_g", "retained_count", "released_count"]
	if not old_v1 and not old_v2 and not old_v3:
		numeric_fields.append_array(["fish_stamina", "line_tension", "fish_distance_cm", "fight_round", "lost_count"])
		numeric_fields.append_array(["last_handling_condition", "handling_count"])
	for field in numeric_fields:
		if not _integer(record[field], 0, 3153600000000):
			return PackedStringArray(["Invalid fishing numeric field."])
	var expected_version := 1 if old_v1 else (2 if old_v2 else (3 if old_v3 else (5 if old_v5 else VERSION)))
	if int(record.version) != expected_version or record.state not in STATES or not record.zone is String or not record.target_species is String or not record.last_outcome is String:
		return PackedStringArray(["Invalid fishing state."])
	if not old_v1:
		if record.rig_mode not in ["lure", "bait"] or not record.bait_item_id is String or (record.rig_mode == "lure" and record.bait_item_id != ""):
			return PackedStringArray(["Invalid rig selection."])
	if not old_v1 and not old_v2:
		if not record.rod_item_id is String or not record.terminal_item_id is String:
			return PackedStringArray(["Invalid tackle identity."])
		if record.state == "idle" and (record.zone != "" or record.target_species != "" or int(record.bite_due_ms) != 0 or record.rod_item_id != "" or record.terminal_item_id != "" or record.bait_item_id != ""):
			return PackedStringArray(["Idle fishing state retains active encounter data."])
		if record.state != "idle" and (not _item_id(record.rod_item_id) or not _item_id(record.terminal_item_id)):
			return PackedStringArray(["Active rig lacks tackle links."])
		if record.state != "idle" and record.rig_mode == "bait" and not _item_id(record.bait_item_id):
			return PackedStringArray(["Active bait rig lacks a canonical bait identity."])
		if record.state == "rigged" and (record.target_species != "" or int(record.bite_due_ms) != 0):
			return PackedStringArray(["Prepared rig has premature encounter data."])
		if record.state == "cast" and int(record.bite_due_ms) == 0:
			return PackedStringArray(["Cast presentation lacks a strike-check time."])
		if record.state == "cast" and not current_v6 and record.target_species == "":
			return PackedStringArray(["Legacy cast lacks a target species."])
		if record.state == "hooked" and (record.target_species == "" or int(record.bite_due_ms) == 0):
			return PackedStringArray(["Hooked encounter lacks a target or bite time."])
	if not old_v1 and not old_v2 and not old_v3:
		if not record.reel_item_id is String or not record.line_item_id is String or not record.fish_cue is String:
			return PackedStringArray(["Invalid fight identity or cue."])
		if record.state == "idle" and (record.reel_item_id != "" or record.line_item_id != "" or not _fight_is_clear(record)):
			return PackedStringArray(["Idle fishing state retains fight data."])
		if record.state != "idle" and (not _item_id(record.reel_item_id) or not _item_id(record.line_item_id)):
			return PackedStringArray(["Active rig lacks reel or line links."])
		if record.state != "hooked" and not _fight_is_clear(record):
			return PackedStringArray(["Fight data exists without a hooked fish."])
		if record.state == "hooked":
			if int(record.last_catch_weight_g) <= 0 or not _integer(record.fish_stamina, 1, 10000) or not _integer(record.line_tension, 101, 899) or not _integer(record.fish_distance_cm, 1, 3499) or not _integer(record.fight_round, 0, 100000) or record.fish_cue not in FIGHT_CUES:
				return PackedStringArray(["Invalid active fish-fight state."])
		if record.last_handling_method not in [""] + LANDING_METHODS or not record.last_handling_method is String or not _integer(record.last_handling_condition, 0, 1000) or not _integer(record.handling_count, 0, 1000000000):
			return PackedStringArray(["Invalid landing outcome record."])
	if current_v6:
		if not record.presentation is String or not record.strike_cue is String:
			return PackedStringArray(["Invalid presentation or strike cue."])
		if record.state in ["idle", "rigged"] and (record.presentation != "" or record.strike_cue != ""):
			return PackedStringArray(["Inactive presentation data remains on the rig."])
		if record.state in ["cast", "hooked"]:
			if not presentation_supported(record.rig_mode, record.presentation):
				return PackedStringArray(["Active presentation is incompatible with the rig."])
			if record.state == "cast" and record.target_species.is_empty() and not record.strike_cue.is_empty():
				return PackedStringArray(["Strike cue exists without an engaged fish."])
			if not record.target_species.is_empty():
				if record.strike_cue not in STRIKE_CUES or record.strike_cue != strike_cue_for(record.target_species, record.presentation):
					return PackedStringArray(["Strike cue does not match the engaged presentation."])
			elif record.state == "hooked":
				return PackedStringArray(["Hooked fish lacks a strike cue."])
	if record.last_outcome.length() > 512 or (not record.zone.is_empty() and record.zone not in Map.ZONE_IDS) or (not record.target_species.is_empty() and record.target_species not in SPECIES) or int(record.bite_due_ms) > now_ms + 3600000 or int(record.last_catch_weight_g) > 100000 or int(record.retained_count) > 1000000000 or int(record.released_count) > 1000000000 or (not old_v1 and not old_v2 and not old_v3 and int(record.lost_count) > 1000000000):
		return PackedStringArray(["Invalid fishing encounter."])
	return PackedStringArray()

'''
regex_once(
    "simulation/fishing.gd",
    r"static func validate\(record: Variant.*?\nstatic func validate_inventory_links",
    new_validate + "static func validate_inventory_links",
)

engagement_helpers = r'''
static func default_presentation(mode: String) -> String:
	if mode == "lure":
		return "steady"
	if mode == "bait":
		return "soak"
	return ""

static func presentation_supported(mode: String, presentation: String) -> bool:
	return (mode == "lure" and presentation in ["steady", "drift"]) or (mode == "bait" and presentation in ["drift", "soak"])

static func _idiv(a: int, b: int) -> int:
	@warning_ignore("integer_division")
	return a / b

static func engagement_score(species: String, mode: String, presentation: String, water: Dictionary, population: int) -> int:
	if population <= 0 or not presentation_supported(mode, presentation):
		return -100000
	var score: int = species_weight(species, mode) * 10 + mini(20, _idiv(population, 3))
	var current: int = int(water.current_cm_s)
	var clarity: int = int(water.clarity_cm)
	var salinity: int = int(water.salinity_deci_ppt)
	var oxygen: int = int(water.oxygen_centi_mg_l)
	var temperature: int = int(water.temperature_centi_c)
	match presentation:
		"steady":
			score += {"mullet": 5, "atlantic_menhaden": 8, "redfish": 25, "speckled_trout": 30, "black_drum": -10}.get(species, 0)
			score += mini(15, _idiv(clarity, 20))
			score += 10 if current <= 35 else -10
		"drift":
			score += {"mullet": 20, "atlantic_menhaden": 20, "redfish": 15, "speckled_trout": 20, "black_drum": 10}.get(species, 0)
			score += mini(15, _idiv(current, 3))
			score += 5 if int(water.depth_cm) >= 50 else -5
		"soak":
			score += {"mullet": 5, "atlantic_menhaden": 0, "redfish": 25, "speckled_trout": 0, "black_drum": 35}.get(species, 0)
			score += 10 if current <= 25 else -10
			score += 10 if salinity >= 50 else 0
	if oxygen < 450:
		score -= 25
	match species:
		"mullet":
			score += 5
		"atlantic_menhaden":
			score += 10 if current >= 5 else -5
		"redfish":
			score += 10 if salinity >= 50 else -5
		"speckled_trout":
			score += 15 if salinity >= 120 else -15
			score += 10 if temperature < 2900 else -10
		"black_drum":
			score += 10 if salinity >= 30 else -5
	return score

static func strike_cue_for(species: String, presentation: String = "") -> String:
	if species in ["redfish", "atlantic_menhaden"]:
		return "pull" if presentation == "soak" else "run"
	if species == "black_drum":
		return "pull"
	return "tap"

static func engagement_result(populations: Dictionary, zone: String, mode: String, presentation: String, water: Dictionary) -> Dictionary:
	if not presentation_supported(mode, presentation):
		return {"engaged": false, "species": "", "cue": "", "score": -100000}
	var best_species := ""
	var best_score := -100000
	for species in SPECIES:
		var species_populations: Variant = populations.get(species)
		var population := 0
		if species_populations is Dictionary:
			population = int(species_populations.get(zone, 0))
		var score := engagement_score(species, mode, presentation, water, population)
		if score > best_score:
			best_score = score
			best_species = species
	if best_species.is_empty() or best_score < ENGAGEMENT_THRESHOLD:
		return {"engaged": false, "species": "", "cue": "", "score": best_score}
	return {"engaged": true, "species": best_species, "cue": strike_cue_for(best_species, presentation), "score": best_score}
'''
replace_once(
    "simulation/fishing.gd",
    "\nstatic func start_fight(record: Dictionary, water: Dictionary) -> void:",
    engagement_helpers + "\nstatic func start_fight(record: Dictionary, water: Dictionary) -> void:",
)
replace_once(
    "simulation/fishing.gd",
    '\trecord.line_item_id = ""\n\tclear_fight(record)',
    '\trecord.line_item_id = ""\n\trecord.presentation = ""\n\trecord.strike_cue = ""\n\tclear_fight(record)',
)

# --- kernel: casting no longer spawns/chooses a fish; presentation and strike checks do ---
replace_once(
    "simulation/kernel.gd",
    '\tworld.fishing.rig_mode = mode\n\tworld.fishing.bait_item_id = bait_item_id if mode == "bait" else ""',
    '\tworld.fishing.rig_mode = mode\n\tworld.fishing.presentation = ""\n\tworld.fishing.strike_cue = ""\n\tworld.fishing.bait_item_id = bait_item_id if mode == "bait" else ""',
)

new_cast_hook = r'''func cast_fishing(presentation: String = "") -> Dictionary:
	if world.fishing.state != "rigged" or world.fishing.zone != world.player_zone:
		return _failure("Prepare a rig at your current water zone first.")
	if presentation.is_empty():
		presentation = Fishing.default_presentation(world.fishing.rig_mode)
	if not Fishing.presentation_supported(world.fishing.rig_mode, presentation):
		return _failure("Choose a presentation compatible with the prepared rig.")
	var link_errors := Fishing.validate_inventory_links(world.fishing, world.inventory)
	if not link_errors.is_empty():
		return _failure(link_errors[0])
	if world.game_time_ms > World.MAX_TIME_MS - Fishing.BITE_DELAY_MS:
		return _failure("Cast exceeds the supported clock range.")
	if world.fishing.rig_mode == "bait":
		world.inventory.entries[world.fishing.bait_item_id].mass_g = maxi(0, int(world.inventory.entries[world.fishing.bait_item_id].mass_g) - 50)
		if world.inventory.entries[world.fishing.bait_item_id].mass_g == 0:
			world.inventory.entries.erase(world.fishing.bait_item_id)
	world.fishing.state = "cast"
	world.fishing.target_species = ""
	world.fishing.presentation = presentation
	world.fishing.strike_cue = ""
	world.fishing.bite_due_ms = world.game_time_ms + Fishing.BITE_DELAY_MS
	_log("fishing_cast", "%s cast into %s with %s presentation; first strike check in 2 game minutes." % [world.fishing.rig_mode.capitalize(), world.player_zone, presentation])
	return {"ok": true, "message": "Cast complete with %s presentation. No species is identified; check for a strike after 2 game minutes." % presentation}

func check_fishing() -> Dictionary:
	if world.fishing.zone != world.player_zone:
		return _failure("Return to the encounter zone or cancel fishing.")
	if world.fishing.state != "cast":
		return _failure("Cast a prepared rig before reading the presentation.")
	if world.game_time_ms < int(world.fishing.bite_due_ms):
		return _failure("No strike window yet; keep working the presentation.")
	var link_errors := Fishing.validate_inventory_links(world.fishing, world.inventory)
	if not link_errors.is_empty():
		return _failure(link_errors[0])
	if not world.fishing.target_species.is_empty():
		return {"ok": true, "status": "strike", "message": "%s strike cue is still present. Set the hook when ready." % String(world.fishing.strike_cue).capitalize()}
	var water: Dictionary = world.environment.water_by_zone[world.player_zone]
	var engagement := Fishing.engagement_result(world.ecology.populations, world.player_zone, world.fishing.rig_mode, world.fishing.presentation, water)
	if not engagement.engaged:
		if world.game_time_ms > World.MAX_TIME_MS - Fishing.BITE_DELAY_MS:
			return _failure("Strike check exceeds the supported clock range.")
		world.fishing.bite_due_ms = world.game_time_ms + Fishing.BITE_DELAY_MS
		_log("fishing_present", "%s %s presentation produced no clear strike at %s; next check in 2 game minutes." % [world.fishing.presentation.capitalize(), world.fishing.rig_mode, world.player_zone])
		return {"ok": true, "status": "no_strike", "message": "No clear strike. The presentation continues; check again after 2 game minutes or cancel and change approach."}
	world.fishing.target_species = String(engagement.species)
	world.fishing.strike_cue = String(engagement.cue)
	_log("fish_strike", "%s strike cue on a %s %s presentation at %s; species remains unidentified." % [world.fishing.strike_cue.capitalize(), world.fishing.presentation, world.fishing.rig_mode, world.player_zone])
	return {"ok": true, "status": "strike", "message": "%s strike cue detected. Species remains unidentified until the hook is set." % world.fishing.strike_cue.capitalize()}

func hook_fishing() -> Dictionary:
	if world.fishing.zone != world.player_zone:
		return _failure("Return to the encounter zone or cancel fishing.")
	if world.fishing.state != "cast":
		return _failure("Nothing is waiting on the line.")
	if world.game_time_ms < int(world.fishing.bite_due_ms):
		return _failure("No strike window yet; keep working the presentation.")
	if world.fishing.target_species.is_empty():
		var strike := check_fishing()
		if not strike.ok or strike.get("status", "") != "strike":
			return strike
	var link_errors := Fishing.validate_inventory_links(world.fishing, world.inventory)
	if not link_errors.is_empty():
		return _failure(link_errors[0])
	world.fishing.state = "hooked"
	world.fishing.last_catch_weight_g = 250 + posmod(world.seed + world.game_time_ms + world.player_zone.length() * 31, 1750)
	Fishing.start_fight(world.fishing, world.environment.water_by_zone[world.player_zone])
	_log("fish_hooked", "Hook set on %s after %s presentation / %s strike; first fight cue: %s." % [world.fishing.target_species, world.fishing.presentation, world.fishing.strike_cue, world.fishing.fish_cue])
	return {"ok": true, "message": "Fish hooked: %s. Read the %s fight cue." % [world.fishing.target_species, world.fishing.fish_cue]}

'''
regex_once(
    "simulation/kernel.gd",
    r"func cast_fishing\(\) -> Dictionary:.*?\nfunc fight_fishing",
    new_cast_hook + "func fight_fishing",
)

# --- world schema 15: Phase 2P schema 14 gets an explicit nested fishing migration ---
replace_once("simulation/world_state.gd", "const SCHEMA_VERSION := 14", "const SCHEMA_VERSION := 15")
replace_once(
    "simulation/world_state.gd",
    '"fishing_rigged", "fishing_cast", "fish_hooked", "fish_fight", "fish_lost", "fish_landed"',
    '"fishing_rigged", "fishing_cast", "fishing_present", "fish_strike", "fish_hooked", "fish_fight", "fish_lost", "fish_landed"',
)
replace_once(
    "simulation/world_state.gd",
    'errors.append_array(Fishing.validate(record.fishing, int(record.clock.game_time_ms), version == 6, version in [7, 8, 9, 10], version == 11, version in [12, 13]))',
    'errors.append_array(Fishing.validate(record.fishing, int(record.clock.game_time_ms), version == 6, version in [7, 8, 9, 10], version == 11, version in [12, 13], version == 14))',
)

schema14_migration = r'''	if is_integer(schema, 14, 14):
		var legacy_errors := _validate(record, 14)
		if not legacy_errors.is_empty():
			return {"ok": false, "message": "Cannot migrate Phase 2P save: " + " ".join(legacy_errors), "code": "invalid"}
		var migrated: Dictionary = record.duplicate(true)
		migrated.schema_version = SCHEMA_VERSION
		migrated.fishing.version = Fishing.VERSION
		if migrated.fishing.state in ["cast", "hooked"]:
			migrated.fishing.presentation = Fishing.default_presentation(migrated.fishing.rig_mode)
			migrated.fishing.strike_cue = Fishing.strike_cue_for(migrated.fishing.target_species, migrated.fishing.presentation) if not migrated.fishing.target_species.is_empty() else ""
		else:
			migrated.fishing.presentation = ""
			migrated.fishing.strike_cue = ""
		var migrated_errors := validate(migrated)
		if not migrated_errors.is_empty():
			return {"ok": false, "message": "Cannot migrate Phase 2P save: " + " ".join(migrated_errors), "code": "invalid"}
		return {"ok": true, "record": migrated, "migrated": true, "message": "Phase 2P save upgraded to presentation/strike causality at the saved game time. Clock paused. No offline time added."}
'''
replace_once(
    "simulation/world_state.gd",
    "\tif is_integer(schema, 1, 13):",
    schema14_migration + "\tif is_integer(schema, 1, 13):",
)
replace_once(
    "simulation/world_state.gd",
    '\t\tvar errors := validate(migrated)\n\t\tif not errors.is_empty():',
    '\t\tif migrated.fishing.state in ["cast", "hooked"]:\n\t\t\tmigrated.fishing.presentation = Fishing.default_presentation(migrated.fishing.rig_mode)\n\t\t\tmigrated.fishing.strike_cue = Fishing.strike_cue_for(migrated.fishing.target_species, migrated.fishing.presentation) if not migrated.fishing.target_species.is_empty() else ""\n\t\telse:\n\t\t\tmigrated.fishing.presentation = ""\n\t\t\tmigrated.fishing.strike_cue = ""\n\t\tvar errors := validate(migrated)\n\t\tif not errors.is_empty():',
)

# --- UI/build metadata ---
replace_once("scripts/main.gd", 'var selected_drag := "balanced"', 'var selected_drag := "balanced"\nvar selected_presentation := "steady"')
replace_once("scripts/main.gd", 'SYSTEMS LAB  /  PHASE 2P', 'SYSTEMS LAB  /  PHASE 2Q')
replace_once("scripts/main.gd", 'var build := "v0.17.0 · local build"', 'var build := "v0.18.0 · local build"')
replace_once("scripts/main.gd", 'info.get("version", "0.17.0")', 'info.get("version", "0.18.0")')
replace_once(
    "scripts/main.gd",
    'column.add_child(_label("Test bite delay: 2 game minutes (20 seconds while the clock runs). Select cut bait in Layers before preparing a bait rig.", 19, MUTED))\n\t_button(column, "Prepare spoon rig", _fish_rig.bind("lure"))\n\t_button(column, "Prepare bait rig with selected item", _fish_rig.bind("bait"))\n\t_button(column, "Cast selected rig", _fish_cast)\n\t_button(column, "Set hook", _fish_hook)',
    'column.add_child(_label("Strike-check delay: 2 game minutes (20 seconds while the clock runs). A cast no longer identifies or guarantees a fish; ecology, water, rig and presentation determine engagement.", 19, MUTED))\n\t_button(column, "Prepare spoon rig", _fish_rig.bind("lure"))\n\t_button(column, "Prepare bait rig with selected item", _fish_rig.bind("bait"))\n\tcolumn.add_child(_label("Choose presentation before casting. Lure supports steady/drift; bait supports drift/soak.", 19, MUTED))\n\trow = _row(column)\n\t_button(row, "Steady", _set_presentation.bind("steady"))\n\t_button(row, "Drift", _set_presentation.bind("drift"))\n\t_button(row, "Soak", _set_presentation.bind("soak"))\n\t_button(column, "Cast selected rig", _fish_cast)\n\t_button(column, "Read presentation / check strike", _fish_check)\n\t_button(column, "Set hook", _fish_hook)',
)
replace_once(
    "scripts/main.gd",
    'fishing_status.text = "HOOKED: %s · %d g\\nCue: %s · Selected drag: %s\\nFish stamina: %d · Line tension: %d / 1000\\nDistance: %.1f m · Fight choices: %d\\n%s\\nRetained %d · Released %d · Lost %d\\nLast handling: %s · condition %d/1000" % [String(f.target_species).replace("_", " ").capitalize(), f.last_catch_weight_g, String(f.fish_cue).to_upper(), selected_drag.capitalize(), f.fish_stamina, f.line_tension, float(f.fish_distance_cm) / 100.0, f.fight_round, "READY TO LAND" if ready else "Keep fighting", f.retained_count, f.released_count, f.lost_count, f.last_handling_method if not f.last_handling_method.is_empty() else "none", f.last_handling_condition]',
    'fishing_status.text = "HOOKED: %s · %d g\\nPresentation: %s · Strike: %s\\nFight cue: %s · Selected drag: %s\\nFish stamina: %d · Line tension: %d / 1000\\nDistance: %.1f m · Fight choices: %d\\n%s\\nRetained %d · Released %d · Lost %d\\nLast handling: %s · condition %d/1000" % [String(f.target_species).replace("_", " ").capitalize(), f.last_catch_weight_g, String(f.presentation).capitalize(), String(f.strike_cue).to_upper(), String(f.fish_cue).to_upper(), selected_drag.capitalize(), f.fish_stamina, f.line_tension, float(f.fish_distance_cm) / 100.0, f.fight_round, "READY TO LAND" if ready else "Keep fighting", f.retained_count, f.released_count, f.lost_count, f.last_handling_method if not f.last_handling_method.is_empty() else "none", f.last_handling_condition]',
)
replace_once(
    "scripts/main.gd",
    'fishing_status.text = "State: %s · Rig: %s\\nTarget: %s · Bite: %s\\nRetained %d · Released %d · Lost %d" % [f.state, f.rig_mode, f.target_species if not f.target_species.is_empty() else "none", Kernel.time_text(int(f.bite_due_ms)) if f.state == "cast" else "not waiting", f.retained_count, f.released_count, f.lost_count]',
    'if f.state == "rigged" and not Fishing.presentation_supported(f.rig_mode, selected_presentation):\n\t\t\t\tselected_presentation = Fishing.default_presentation(f.rig_mode)\n\t\t\tvar presentation_text := String(f.presentation).capitalize() if f.state == "cast" else selected_presentation.capitalize()\n\t\t\tvar strike_text := (String(f.strike_cue).to_upper() + " cue") if f.state == "cast" and not f.strike_cue.is_empty() else ("waiting" if f.state == "cast" else "none")\n\t\t\tfishing_status.text = "State: %s · Rig: %s\\nPresentation: %s · Strike: %s\\nSpecies: unknown until hooked\\nNext check: %s\\nRetained %d · Released %d · Lost %d" % [f.state, f.rig_mode, presentation_text, strike_text, Kernel.time_text(int(f.bite_due_ms)) if f.state == "cast" else "not waiting", f.retained_count, f.released_count, f.lost_count]',
)
replace_once(
    "scripts/main.gd",
    'func _fish_cast() -> void:\n\tif _can_act():\n\t\t_after_action(kernel.cast_fishing())\n\nfunc _fish_hook() -> void:',
    'func _fish_cast() -> void:\n\tif _can_act():\n\t\t_after_action(kernel.cast_fishing(selected_presentation))\n\nfunc _fish_check() -> void:\n\tif _can_act():\n\t\t_after_action(kernel.check_fishing())\n\nfunc _fish_hook() -> void:',
)
replace_once(
    "scripts/main.gd",
    'func _set_drag(value: String) -> void:',
    'func _set_presentation(value: String) -> void:\n\tif value in Fishing.PRESENTATIONS:\n\t\tselected_presentation = value\n\t\t_status("Presentation set to %s for the next cast." % value)\n\t\t_refresh()\n\nfunc _set_drag(value: String) -> void:',
)
replace_once(
    "scripts/main.gd",
    '\t\t_after_action(kernel.rig_fishing(mode, bait_id))',
    '\t\tvar result := kernel.rig_fishing(mode, bait_id)\n\t\tif result.ok:\n\t\t\tselected_presentation = Fishing.default_presentation(mode)\n\t\t_after_action(result)',
)

replace_once("tools/prepare_build.py", '"version": "0.17.0", "phase": "2P"', '"version": "0.18.0", "phase": "2Q"')
replace_once("tools/prepare_build.py", 'version/name="0.17.0-dev.{number}"', 'version/name="0.18.0-dev.{number}"')
replace_once("tools/prepare_build.py", 'Prepared Phase 2P build', 'Prepared Phase 2Q build')

# --- dedicated gate + roadmap docs ---
phase_test = r'''extends SceneTree

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
	legacy.fishing.erase("presentation")
	legacy.fishing.erase("strike_cue")
	legacy.fishing.target_species = "redfish"
	var legacy_time := int(legacy.clock.game_time_ms)
	var migrated := World.migrate_record(legacy)
	if not migrated.ok or not migrated.migrated or int(migrated.record.schema_version) != World.SCHEMA_VERSION or int(migrated.record.clock.game_time_ms) != legacy_time or migrated.record.fishing.presentation != "steady" or migrated.record.fishing.strike_cue != Fishing.strike_cue_for("redfish", "steady"):
		fail("2Q: Phase 2P save did not migrate without hidden time advancement")
		return

	var corrupt := migrated.record.duplicate(true)
	corrupt.fishing.presentation = "soak"
	if World.validate(corrupt).is_empty():
		fail("2Q: current save validation accepted an incompatible active presentation")
		return
	print("Phase 2Q presentation/strike causality invariants: passed.")
	quit(0)
'''
(ROOT / "tests/phase_2q.gd").write_text(phase_test)

phase_doc = '''# Phase 2Q — presentation and strike causality\n\nDevelopment v0.18.0. World schema 15 / fishing record v6. This slice removes the guaranteed, premature fish selection that previously happened at cast.\n\n## Delivered\n\n- Casts persist an explicit `steady`, `drift`, or `soak` presentation; lure supports steady/drift and bait supports drift/soak.\n- Casting no longer selects a species and no longer fails merely because the local ecology count is zero. A physically valid cast can simply produce no strike.\n- A strike check occurs after the existing two-game-minute systems-lab delay. Local population, water state, rig mode and presentation feed a deterministic engagement score; there is no hidden random bite roll.\n- No-strike checks keep the rig cast and schedule another two-game-minute check without spawning fish, changing ecology or consuming RNG.\n- When a fish engages, the authoritative state stores the engaged species and a strike cue, but player-facing feedback exposes only the cue until the hook is set.\n- Hooking reveals the species and then enters the existing fight model unchanged. Historical direct `Set hook` test paths still resolve the due strike check internally so older gate fixtures remain compatible.\n- Waiting casts and developed strikes survive save/reload exactly. Phase 2P schema-14 saves migrate to schema 15 at the saved game time with no offline advancement. Existing cast/hooked Phase 2P encounters are preserved with a deterministic default presentation and strike cue.\n- Current-save validation rejects incompatible presentation/rig pairs and impossible strike-cue combinations.\n\n## Systems-lab coefficients\n\nEngagement uses deterministic prototype coefficients for rig preference, presentation, local abundance, current, clarity, salinity, oxygen, temperature and depth. They prove causal plumbing only; they are not final species behavior or catch-rate tuning. The UI intentionally does not display an engagement score or bite percentage.\n\n## Android phone gate\n\n1. Install the newest APK as an update and confirm `v0.18.0` / `PHASE 2Q`. Load the existing Phase 2P save and confirm the clock has not advanced while the app was closed.\n2. Prepare a spoon rig. Choose **Steady**, cast, and confirm the fishing status says species is unknown and records the steady presentation.\n3. Before two game minutes, tap **Read presentation / check strike** and confirm the early check is rejected without changing the cast.\n4. Run/pause the clock until the strike-check time, then tap **Read presentation / check strike**. Confirm the status exposes a strike cue but still does not name the species. Save/reload and confirm presentation/cue remain unchanged.\n5. Tap **Set hook**. Confirm the species is revealed only now and the existing fight controls continue normally.\n6. Cancel and prepare another spoon rig. Select **Soak** and attempt to cast; confirm the incompatible presentation is rejected and the rig remains prepared.\n7. If using a bait rig, confirm **Soak** or **Drift** is accepted while **Steady** is rejected.\n\n## Deliberate limits\n\nThis gate does not implement player casting aim/trajectory, lure animation, exact sensory fields, individual fish positions, bite theft, strike expiration, hook-set timing/force, hook placement, skill/attribute resolution or final XP. Those remain later slices. The two-minute check interval and engagement coefficients are testing fixtures, not final bite physics.\n'''
(ROOT / "docs/PHASE_2Q.md").write_text(phase_doc)

replace_once(
    "docs/IMPLEMENTATION_ORDER.md",
    '''Lettered slices 2C–2P now cover deterministic environmental records, five-species population accounting, coarse player condition, the fishing state machine, physical item identity and storage, explicit fish processing, persistent tackle links, the timed fish-fight/landing loop, explicit landing/post-catch condition, and deeper full-rig causality. Each phase document records its own limits and phone gate. These are connected systems-lab fixtures, not completed versions of master phases 5–8.\n\nPhase 2P adds persistent rod/reel/line/terminal condition, deterministic full-rig wear, condition-dependent load limits, explicit loose/balanced/tight drag choices, weakest-link failure ownership, auditable failed rounds, broken-tackle rejection, and camp service/replacement. Its full code audit must pass automation and its Android checklist must pass on the physical phone before Phase 2Q depends on it. The next lettered slice is intentionally not declared complete or locked in by this roadmap until that gate closes. Camping, survival fidelity, individual wildlife behavior, the dedicated map and 3D presentation remain later gates. Passing automation does not substitute for physical Android testing or mean the complete initial survival loop is playable.\n''',
    '''Lettered slices 2C–2Q now cover deterministic environmental records, five-species population accounting, coarse player condition, the fishing state machine, physical item identity and storage, explicit fish processing, persistent tackle links, the timed fish-fight/landing loop, explicit landing/post-catch condition, deeper full-rig causality, and the first causal presentation/strike layer. Each phase document records its own limits and phone gate. These are connected systems-lab fixtures, not completed versions of master phases 5–8.\n\nPhase 2Q removes species selection from casting and makes engagement depend on actual local ecology, water, rig mode and a persisted presentation choice. A strike cue may become observable after the test delay while species identity stays hidden until the hook is set; no-fish water can now accept a cast and correctly produce no strike. Schema 15 migrates Phase 2P saves without advancing closed-game time. Phase 2Q must pass automation and its physical Android checklist before Phase 2R depends on it. The next proposed fishing slice is strike-response/hook-set causality: timing/force and hook placement feeding retention, injury and the existing fight state. Camping, survival fidelity, individual wildlife behavior, the dedicated map and 3D presentation remain later gates. Passing automation does not substitute for physical Android testing or mean the complete initial survival loop is playable.\n''',
)

replace_once(
    "tools/check.sh",
    'timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2p.gd 2>&1 | tee "$project_root/build/phase-2p.log"\n',
    'timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2p.gd 2>&1 | tee "$project_root/build/phase-2p.log"\ntimeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2q.gd 2>&1 | tee "$project_root/build/phase-2q.log"\n',
)
replace_once(
    "tools/check.sh",
    '"$project_root/build/phase-2o.log" "$project_root/build/phase-2p.log" "$project_root/build/save-write.log"',
    '"$project_root/build/phase-2o.log" "$project_root/build/phase-2p.log" "$project_root/build/phase-2q.log" "$project_root/build/save-write.log"',
)

print("Phase 2Q transformation staged.")
