extends RefCounted
## Phase 2F deterministic fishing action state. Test encounters only.

const VERSION := 3
const Map = preload("res://simulation/testbed_map.gd")
const STATES := ["idle", "rigged", "cast", "hooked"]
const SPECIES := ["mullet", "atlantic_menhaden", "redfish", "speckled_trout", "black_drum"]
const BITE_DELAY_MS := 120000 # Two game minutes for phone-system testing.

static func create() -> Dictionary:
	return {"version": VERSION, "state": "idle", "zone": "", "target_species": "", "bite_due_ms": 0, "last_outcome": "", "last_catch_weight_g": 0, "retained_count": 0, "released_count": 0, "rig_mode": "lure", "bait_item_id": "", "rod_item_id": "", "terminal_item_id": ""}

static func validate(record: Variant, now_ms: int, legacy: bool = false, old_v1: bool = false, old_v2: bool = false) -> PackedStringArray:
	var keys := ["version", "state", "zone", "target_species", "bite_due_ms", "last_outcome", "last_catch_weight_g", "retained_count", "released_count"]
	if not legacy and not old_v1:
		keys.append_array(["rig_mode", "bait_item_id"])
	if not legacy and not old_v1 and not old_v2:
		keys.append_array(["rod_item_id", "terminal_item_id"])
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
	var expected_version := 1 if old_v1 else (2 if old_v2 else VERSION)
	if int(record.version) != expected_version or not record.state in STATES or not record.zone is String or not record.target_species is String or not record.last_outcome is String:
		return PackedStringArray(["Invalid fishing state."])
	if not old_v1 and (record.rig_mode not in ["lure", "bait"] or not record.bait_item_id is String or (record.rig_mode == "lure" and record.bait_item_id != "")):
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
		if record.state in ["cast", "hooked"] and (record.target_species == "" or int(record.bite_due_ms) == 0):
			return PackedStringArray(["Active encounter lacks a target or bite time."])
	if (not record.zone.is_empty() and not record.zone in Map.ZONE_IDS) or (not record.target_species.is_empty() and not record.target_species in SPECIES) or int(record.bite_due_ms) < 0 or int(record.bite_due_ms) > now_ms + 3600000 or int(record.last_catch_weight_g) < 0 or int(record.last_catch_weight_g) > 100000 or int(record.retained_count) < 0 or int(record.released_count) < 0:
		return PackedStringArray(["Invalid fishing encounter."])
	return PackedStringArray()

static func validate_inventory_links(record: Dictionary, inventory: Dictionary) -> PackedStringArray:
	if record.state == "idle":
		return PackedStringArray()
	var rod: Variant = inventory.entries.get(record.rod_item_id)
	var terminal: Variant = inventory.entries.get(record.terminal_item_id)
	if not rod is Dictionary or rod.kind != "test_rod" or rod.container != "pack":
		return PackedStringArray(["Rig rod is not carried."])
	var expected_terminal := "test_spoon" if record.rig_mode == "lure" else "test_hook"
	if not terminal is Dictionary or terminal.kind != expected_terminal or terminal.container != "pack":
		return PackedStringArray(["Rig terminal tackle is incompatible or not carried."])
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
