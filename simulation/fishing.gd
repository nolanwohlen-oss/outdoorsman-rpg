extends RefCounted
## Deterministic fishing encounter and fight rules for the systems lab.

const VERSION := 6
const Map = preload("res://simulation/testbed_map.gd")
const STATES := ["idle", "rigged", "cast", "hooked"]
const SPECIES := ["mullet", "atlantic_menhaden", "redfish", "speckled_trout", "black_drum"]
const BITE_DELAY_MS := 120000 # Two game minutes for phone-system testing.
const FIGHT_ACTION_MS := 30000
const LANDING_ACTION_MS := 60000
const FIGHT_ACTIONS := ["give_line", "pressure", "reel"]
const DRAG_SETTINGS := ["loose", "balanced", "tight"]
const PRESENTATIONS := ["steady", "drift", "soak"]
const STRIKE_CUES := ["tap", "pull", "run"]
const ENGAGEMENT_THRESHOLD := 65
const FIGHT_CUES := ["surge", "pull", "slack", "tired"]
const READY_STAMINA := 200
const READY_DISTANCE_CM := 250
const SLACK_LIMIT := 100
const OVERLOAD_LIMIT := 900
const COVER_DISTANCE_CM := 3500
const LANDING_METHODS := ["hand", "net", "gaff"]

static func create() -> Dictionary:
	return {
		"version": VERSION,
		"state": "idle",
		"zone": "",
		"target_species": "",
		"bite_due_ms": 0,
		"last_outcome": "",
		"last_catch_weight_g": 0,
		"retained_count": 0,
		"released_count": 0,
		"rig_mode": "lure",
		"presentation": "",
		"strike_cue": "",
		"bait_item_id": "",
		"rod_item_id": "",
		"terminal_item_id": "",
		"reel_item_id": "",
		"line_item_id": "",
		"fish_stamina": 0,
		"line_tension": 0,
		"fish_distance_cm": 0,
		"fight_round": 0,
		"fish_cue": "",
		"lost_count": 0,
		"last_handling_method": "",
		"last_handling_condition": 0,
		"handling_count": 0,
	}

static func validate(record: Variant, now_ms: int, legacy: bool = false, old_v1: bool = false, old_v2: bool = false, old_v3: bool = false, old_v5: bool = false) -> PackedStringArray:
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

static func validate_inventory_links(record: Dictionary, inventory: Dictionary) -> PackedStringArray:
	if record.state == "idle":
		return PackedStringArray()
	var rod: Variant = inventory.entries.get(record.rod_item_id)
	var reel: Variant = inventory.entries.get(record.reel_item_id)
	var line: Variant = inventory.entries.get(record.line_item_id)
	var terminal: Variant = inventory.entries.get(record.terminal_item_id)
	if not rod is Dictionary or rod.kind != "test_rod" or rod.container != "pack":
		return PackedStringArray(["Rig rod is not carried."])
	if not reel is Dictionary or reel.kind != "test_reel" or reel.container != "pack":
		return PackedStringArray(["Rig reel is not carried."])
	if not line is Dictionary or line.kind != "test_line" or line.container != "pack":
		return PackedStringArray(["Rig line is not carried."])
	var expected_terminal := "test_spoon" if record.rig_mode == "lure" else "test_hook"
	if not terminal is Dictionary or terminal.kind != expected_terminal or terminal.container != "pack":
		return PackedStringArray(["Rig terminal tackle is incompatible or not carried."])
	for component in [rod, reel, line, terminal]:
		if int(component.condition) == 0:
			return PackedStringArray(["Active rig contains broken tackle."])
	if record.rig_mode == "bait" and record.state == "rigged":
		var bait: Variant = inventory.entries.get(record.bait_item_id)
		if not bait is Dictionary or bait.kind != "cut_bait" or bait.container != "pack" or int(bait.mass_g) < 50:
			return PackedStringArray(["Rig bait is unavailable."])
	return PackedStringArray()

static func species_weight(species: String, mode: String) -> int:
	if mode == "lure":
		return {"mullet": 1, "atlantic_menhaden": 1, "redfish": 5, "speckled_trout": 6, "black_drum": 1}.get(species, 0)
	if mode == "bait":
		return {"mullet": 2, "atlantic_menhaden": 2, "redfish": 6, "speckled_trout": 3, "black_drum": 6}.get(species, 0)
	return 0

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

static func start_fight(record: Dictionary, water: Dictionary) -> void:
	var species_factor: int = {"mullet": 0, "atlantic_menhaden": 80, "redfish": 260, "speckled_trout": 200, "black_drum": 320}.get(record.target_species, 0)
	var weight := int(record.last_catch_weight_g)
	var temperature_load := int(maxi(0, int(water.temperature_centi_c) - 1800) / 10)
	var oxygen_penalty := maxi(0, 700 - int(water.oxygen_centi_mg_l))
	record.fish_stamina = clampi(400 + int(weight / 2) + species_factor + temperature_load - oxygen_penalty, 350, 3000)
	record.line_tension = 500
	record.fish_distance_cm = clampi(1000 + int(weight / 2) + int(water.current_cm_s) * 10, 1000, 3000)
	record.fight_round = 0
	record.fish_cue = cue_for(record, water)

static func resolve_round(record: Dictionary, action: String, water: Dictionary, drag: String = "balanced", overload_limit: int = OVERLOAD_LIMIT) -> Dictionary:
	if record.state != "hooked" or action not in FIGHT_ACTIONS or drag not in DRAG_SETTINGS:
		return {"ok": false, "message": "Choose a valid action and drag setting for a hooked fish."}
	overload_limit = clampi(overload_limit, 450, OVERLOAD_LIMIT)
	var stamina := int(record.fish_stamina)
	var tension := int(record.line_tension)
	var distance := int(record.fish_distance_cm)
	match String(record.fish_cue):
		"surge":
			if action == "give_line":
				tension = maxi(300, tension - 200)
				stamina -= 80
				distance += 120
			elif action == "pressure":
				tension += 420
				stamina -= 100
				distance += 450
			else:
				tension += 480
				stamina -= 130
				distance -= 80
		"pull":
			if action == "pressure":
				tension = 560
				stamina -= 180
				distance -= 80
			elif action == "give_line":
				tension -= 250
				stamina -= 40
				distance += 350
			else:
				tension += 250
				stamina -= 90
				distance -= 100
		"slack":
			if action == "reel":
				tension = 480
				stamina -= 70
				distance -= 240
			elif action == "give_line":
				tension -= 450
				stamina -= 20
				distance += 250
			else:
				tension += 240
				stamina -= 60
				distance += 50
		"tired":
			if action == "reel":
				tension = 520
				stamina -= 200
				distance -= 380
			elif action == "give_line":
				tension -= 260
				stamina -= 30
				distance += 280
			else:
				tension += 180
				stamina -= 100
				distance -= 20
	match drag:
		"loose":
			tension -= 120
			distance += 80
			stamina += 35
		"tight":
			tension += 120
			distance -= 80
			stamina -= 35
	record.fish_stamina = maxi(1, stamina)
	record.line_tension = tension
	record.fish_distance_cm = maxi(1, distance)
	record.fight_round = int(record.fight_round) + 1
	if tension >= overload_limit:
		return {"ok": true, "status": "overload", "message": "The fish broke free under excessive line tension."}
	if tension <= SLACK_LIMIT:
		return {"ok": true, "status": "slack", "message": "The hook pulled free when the line went slack."}
	if distance >= COVER_DISTANCE_CM:
		return {"ok": true, "status": "cover", "message": "The fish reached cover and broke free."}
	record.line_tension = clampi(tension, SLACK_LIMIT + 1, OVERLOAD_LIMIT - 1)
	record.fish_distance_cm = clampi(distance, 1, COVER_DISTANCE_CM - 1)
	record.fish_cue = cue_for(record, water)
	return {"ok": true, "status": "continue", "message": "Pressure held; read the next fish cue."}

static func fight_power(record: Dictionary, water: Dictionary) -> int:
	var species_factor: int = {"mullet": 0, "atlantic_menhaden": 30, "redfish": 120, "speckled_trout": 100, "black_drum": 150}.get(record.target_species, 0)
	return int(record.last_catch_weight_g / 10) + species_factor + int(water.current_cm_s) * 2

static func cue_for(record: Dictionary, water: Dictionary) -> String:
	if int(record.fish_stamina) <= 350:
		return "tired"
	var sequence: Array[String] = ["surge", "pull", "slack", "pull"]
	return sequence[posmod(int(record.fight_round) + fight_power(record, water), sequence.size())]

static func landing_ready(record: Dictionary) -> bool:
	return record.state == "hooked" and int(record.fish_stamina) <= READY_STAMINA and int(record.fish_distance_cm) <= READY_DISTANCE_CM

static func landing_profile(method: String) -> Dictionary:
	return {
		"hand": {"minutes": 1, "retain_condition": 820, "release_condition": 700, "release_allowed": true},
		"net": {"minutes": 2, "retain_condition": 960, "release_condition": 940, "release_allowed": true},
		"gaff": {"minutes": 1, "retain_condition": 1000, "release_condition": 0, "release_allowed": false},
	}.get(method, {})

static func clear_fight(record: Dictionary) -> void:
	record.fish_stamina = 0
	record.line_tension = 0
	record.fish_distance_cm = 0
	record.fight_round = 0
	record.fish_cue = ""

static func clear_active(record: Dictionary) -> void:
	record.state = "idle"
	record.zone = ""
	record.target_species = ""
	record.bite_due_ms = 0
	record.bait_item_id = ""
	record.rod_item_id = ""
	record.terminal_item_id = ""
	record.reel_item_id = ""
	record.line_item_id = ""
	record.presentation = ""
	record.strike_cue = ""
	clear_fight(record)

static func _fight_is_clear(record: Dictionary) -> bool:
	return int(record.fish_stamina) == 0 and int(record.line_tension) == 0 and int(record.fish_distance_cm) == 0 and int(record.fight_round) == 0 and record.fish_cue == ""

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value == floor(value) and value >= minimum and value <= maximum

static func _item_id(value: String) -> bool:
	if not value.begins_with("item_") or not value.trim_prefix("item_").is_valid_int():
		return false
	var serial := int(value.trim_prefix("item_"))
	return serial > 0 and value == "item_%d" % serial

static func normalized(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = normalized(value[key])
		return result
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	return value
