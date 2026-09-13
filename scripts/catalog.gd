extends RefCounted
## Phase 1 presentation catalog. These are not canonical simulation records.

const PATH := "res://data/testbed.json"

static func read() -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(PATH)) != OK:
		push_error("Testbed catalog is not valid JSON: " + parser.get_error_message())
		return {}
	if not parser.data is Dictionary:
		push_error("Testbed catalog must be an object.")
		return {}
	return parser.data

static func validate(catalog: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if catalog.get("catalog_version") != 1:
		errors.append("Unsupported catalog version.")
	for section in ["zones", "species", "layers"]:
		if not catalog.get(section) is Array or catalog[section].is_empty():
			errors.append("Missing catalog section: " + section)
	if not errors.is_empty():
		return errors
	var zone_ids: Dictionary = {}
	for section in ["zones", "species"]:
		var seen: Dictionary = {}
		for entry in catalog[section]:
			if not entry is Dictionary or not entry.get("id") is String or not entry.get("name") is String:
				errors.append("Invalid entry in " + section)
				continue
			if entry.id.is_empty() or entry.name.is_empty() or seen.has(entry.id):
				errors.append("Empty or duplicate entry in " + section)
			seen[entry.id] = entry
		if section == "zones":
			zone_ids = seen
	for zone_id in zone_ids:
		var zone: Dictionary = zone_ids[zone_id]
		if not zone.get("neighbors") is Array:
			errors.append("Missing connections for " + zone_id)
			continue
		for neighbor in zone.neighbors:
			if neighbor == zone_id or not zone_ids.has(neighbor):
				errors.append("Invalid connection from " + zone_id)
			elif not zone_ids[neighbor].get("neighbors", []).has(zone_id):
				errors.append("Connection is not reciprocal: " + zone_id)
	return errors
