extends RefCounted
## Phase 2F deterministic fishing action state. Test encounters only.

const VERSION := 1
const Map = preload("res://simulation/testbed_map.gd")
const STATES := ["idle", "rigged", "cast", "hooked"]
const SPECIES := ["mullet", "atlantic_menhaden", "redfish", "speckled_trout", "black_drum"]

static func create() -> Dictionary:
	return {"version": VERSION, "state": "idle", "zone": "", "target_species": "", "bite_due_ms": 0, "last_outcome": ""}

static func validate(record: Variant, now_ms: int) -> PackedStringArray:
	var keys := ["version", "state", "zone", "target_species", "bite_due_ms", "last_outcome"]
	if not record is Dictionary or record.size() != keys.size() or not record.has_all(keys):
		return PackedStringArray(["Fishing state has missing or unknown fields."])
	if int(record.version) != VERSION or not record.state in STATES or not record.zone is String or not record.target_species is String or not record.last_outcome is String:
		return PackedStringArray(["Invalid fishing state."])
	if (not record.zone.is_empty() and not record.zone in Map.ZONE_IDS) or (not record.target_species.is_empty() and not record.target_species in SPECIES) or int(record.bite_due_ms) < 0 or int(record.bite_due_ms) > now_ms + 3600000:
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
