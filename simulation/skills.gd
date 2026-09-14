extends RefCounted
## Phase 2R Angling progression ledger. XP is authoritative; levels are derived.
## Intermediate thresholds are provisional systems-lab interpolation while preserving
## every canonical Master Skill Sheet v12 anchor exactly.

const VERSION := 1
const MAX_LEVEL := 99
const MAX_XP := 6517215
const SUBSKILLS := [
	"fish_location_water_reading",
	"casting_presentation",
	"tackle_rigging_bait_handling",
	"hooking_fighting_landing_release",
]
const LABELS := {
	"fish_location_water_reading": "Fish Location and Water Reading",
	"casting_presentation": "Casting and Presentation",
	"tackle_rigging_bait_handling": "Tackle Rigging and Bait Handling",
	"hooking_fighting_landing_release": "Hooking, Fighting, Landing and Release",
}
const ANCHOR_LEVELS := [1, 10, 25, 50, 75, 92, 99]
const ANCHOR_XP := [0, 577, 3921, 50666, 605210, 3258626, 6517215]
const RIG_SIGNATURES := ["lure", "bait"]

# Stable prototype completion records. Challenge/outcome/quality/novelty multipliers
# remain 1.00x in 2R. Later gates may extend them without changing these base IDs.
const ACTIONS := {
	"fishing_rig_functional": {"subskill": "tackle_rigging_bait_handling", "base_xp": 5},
	"fishing_cast_purposeful": {"subskill": "casting_presentation", "base_xp": 1},
	"fishing_strike_read": {"subskill": "fish_location_water_reading", "base_xp": 2},
	"fishing_hookset": {"subskill": "hooking_fighting_landing_release", "base_xp": 3},
	"fishing_fight_control": {"subskill": "hooking_fighting_landing_release", "base_xp": 1},
	"fishing_land_ordinary": {"subskill": "hooking_fighting_landing_release", "base_xp": 10},
}

static func create() -> Dictionary:
	var angling: Dictionary = {}
	for id in SUBSKILLS:
		angling[id] = {"xp": 0}
	return {
		"version": VERSION,
		"angling": angling,
		"rig_signatures": [],
		"cast_xp_pending": false,
	}

static func normalized(record: Dictionary) -> Dictionary:
	var result: Dictionary = record.duplicate(true)
	result.version = int(result.version)
	for id in SUBSKILLS:
		result.angling[id].xp = int(result.angling[id].xp)
	result.cast_xp_pending = bool(result.cast_xp_pending)
	return result

static func validate(record: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not record is Dictionary or record.size() != 4 or not record.has_all(["version", "angling", "rig_signatures", "cast_xp_pending"]):
		return PackedStringArray(["Skill record has missing or unknown fields."])
	if not _integer(record.version, VERSION, VERSION):
		errors.append("Invalid skill record version.")
	if typeof(record.cast_xp_pending) != TYPE_BOOL:
		errors.append("Invalid cast XP completion guard.")
	if not record.angling is Dictionary or record.angling.size() != SUBSKILLS.size():
		errors.append("Invalid Angling skill record.")
	else:
		for id in SUBSKILLS:
			var entry: Variant = record.angling.get(id)
			if not entry is Dictionary or entry.size() != 1 or not entry.has("xp") or not _integer(entry.xp, 0, MAX_XP):
				errors.append("Invalid Angling subskill: %s." % id)
	var signatures: Variant = record.rig_signatures
	if not signatures is Array or signatures.size() > RIG_SIGNATURES.size():
		errors.append("Invalid rig XP guard record.")
	else:
		var seen: Dictionary = {}
		for signature in signatures:
			if not signature is String or signature not in RIG_SIGNATURES or seen.has(signature):
				errors.append("Invalid or duplicate rig XP guard signature.")
				break
			seen[signature] = true
	return errors

static func threshold_for_level(level: int) -> int:
	level = clampi(level, 1, MAX_LEVEL)
	for index in ANCHOR_LEVELS.size():
		if level == int(ANCHOR_LEVELS[index]):
			return int(ANCHOR_XP[index])
	for index in range(ANCHOR_LEVELS.size() - 1):
		var lower_level := int(ANCHOR_LEVELS[index])
		var upper_level := int(ANCHOR_LEVELS[index + 1])
		if level <= lower_level or level >= upper_level:
			continue
		var lower_xp := int(ANCHOR_XP[index])
		var upper_xp := int(ANCHOR_XP[index + 1])
		var t := float(level - lower_level) / float(upper_level - lower_level)
		var low_log := log(float(lower_xp + 1))
		var high_log := log(float(upper_xp + 1))
		var raw := int(round(exp(lerpf(low_log, high_log, t)) - 1.0))
		# Preserve strict monotonicity even if rounding compresses an early interval.
		var minimum := lower_xp + (level - lower_level)
		var maximum := upper_xp - (upper_level - level)
		return clampi(raw, minimum, maximum)
	return MAX_XP

static func level_for_xp(xp: int) -> int:
	xp = clampi(xp, 0, MAX_XP)
	var result := 1
	for level in range(2, MAX_LEVEL + 1):
		if xp < threshold_for_level(level):
			break
		result = level
	return result

static func subskill_xp(record: Dictionary, id: String) -> int:
	if id not in SUBSKILLS:
		return -1
	return int(record.angling[id].xp)

static func subskill_level(record: Dictionary, id: String) -> int:
	var xp := subskill_xp(record, id)
	return -1 if xp < 0 else level_for_xp(xp)

static func base_average(record: Dictionary) -> float:
	var total := 0
	for id in SUBSKILLS:
		total += subskill_level(record, id)
	return float(total) / float(SUBSKILLS.size())

static func displayed_base_level(record: Dictionary) -> int:
	return int(floor(base_average(record)))

static func progress(record: Dictionary, id: String) -> Dictionary:
	if id not in SUBSKILLS:
		return {}
	var xp := subskill_xp(record, id)
	var level := level_for_xp(xp)
	var next := MAX_XP if level == MAX_LEVEL else threshold_for_level(level + 1)
	return {
		"id": id,
		"label": String(LABELS[id]),
		"xp": xp,
		"level": level,
		"next_xp": next,
		"remaining": 0 if level == MAX_LEVEL else next - xp,
	}

static func award(record: Dictionary, action_id: String) -> Dictionary:
	var definition: Variant = ACTIONS.get(action_id)
	if not definition is Dictionary:
		return {"ok": false, "message": "Unknown skill completion action."}
	var subskill := String(definition.subskill)
	var base_xp := int(definition.base_xp)
	var current := subskill_xp(record, subskill)
	if current < 0:
		return {"ok": false, "message": "Skill record is missing the target subskill."}
	var old_level := level_for_xp(current)
	var updated := mini(MAX_XP, current + base_xp)
	record.angling[subskill].xp = updated
	var new_level := level_for_xp(updated)
	return {
		"ok": true,
		"action_id": action_id,
		"subskill": subskill,
		"label": String(LABELS[subskill]),
		"base_xp": base_xp,
		"xp_awarded": updated - current,
		"old_level": old_level,
		"new_level": new_level,
		"cumulative_xp": updated,
	}

static func rig_signature_is_new(record: Dictionary, signature: String) -> bool:
	return signature in RIG_SIGNATURES and not record.rig_signatures.has(signature)

static func remember_rig_signature(record: Dictionary, signature: String) -> void:
	if signature not in RIG_SIGNATURES or record.rig_signatures.has(signature):
		return
	record.rig_signatures.append(signature)

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and value >= minimum and value <= maximum and value == floor(value)
