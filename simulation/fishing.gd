extends RefCounted
## Phase 2F deterministic fishing action state. Test encounters only.

const VERSION := 2
const Map = preload("res://simulation/testbed_map.gd")
const STATES := ["idle", "rigged", "cast", "hooked"]
const SPECIES := ["mullet", "atlantic_menhaden", "redfish", "speckled_trout", "black_drum"]

static func create() -> Dictionary:
	return {"version": VERSION, "state": "idle", "zone": "", "target_species": "", "bite_due_ms": 0, "last_outcome": "", "last_catch_weight_g": 0, "retained_count": 0, "released_count": 0, "rig_mode": "lure", "bait_item_id": ""}

static func validate(record: Variant, now_ms: int, legacy: bool = false, old_v1: bool = false) -> PackedStringArray:
	var keys := ["version", "state", "zone", "target_species", "bite_due_ms", "last_outcome", "last_catch_weight_g", "retained_count", "released_count"]
	if not legacy and not old_v1:
		keys.append_array(["rig_mode", "bait_item_id"])
	if legacy:
		keys = ["version", "state", "zone", "target_species", "bite_due_ms", "last_outcome"]
	if not record is Dictionary or record.size() != keys.size() or not record.has_all(keys):
		return PackedStringArray(["Fishing state has missing or unknown fields."])
	if legacy:
		var expanded: Dictionary = record.duplicate(true)
		expanded.last_catch_weight_g = 0
		expanded.retained_count = 0
		expanded.released_count = 0
		return validate(expanded, now_ms, false, true)
	for field in ["version", "bite_due_ms", "last_catch_weight_g", "retained_count", "released_count"]:
		if typeof(record[field]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(record[field])) or record[field] != floor(record[field]) or record[field] < 0 or record[field] > 3153600000000:
			return PackedStringArray(["Invalid fishing numeric field."])
	if int(record.version) != (1 if old_v1 else VERSION) or not record.state in STATES or not record.zone is String or not record.target_species is String or not record.last_outcome is String:
		return PackedStringArray(["Invalid fishing state."])
	if not old_v1 and (record.rig_mode not in ["lure", "bait"] or not record.bait_item_id is String or (record.rig_mode == "lure" and record.bait_item_id != "")):
		return PackedStringArray(["Invalid rig selection."])
	if (not record.zone.is_empty() and not record.zone in Map.ZONE_IDS) or (not record.target_species.is_empty() and not record.target_species in SPECIES) or int(record.bite_due_ms) < 0 or int(record.bite_due_ms) > now_ms + 3600000 or int(record.last_catch_weight_g) < 0 or int(record.last_catch_weight_g) > 100000 or int(record.retained_count) < 0 or int(record.released_count) < 0:
		return PackedStringArray(["Invalid fishing encounter."])
	return PackedStringArray()

static func normalized(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = normalized(value[key])
		return result
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	return value
