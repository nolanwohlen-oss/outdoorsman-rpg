extends RefCounted
## Canonical Phase 2B map and habitat contract. It is independent from UI catalog layout.

const MAP_VERSION := 2
const ZONE_IDS := ["open_water", "tidal_channel", "marsh_edge", "shallow_flat", "sandy_shore", "elevated_camp"]

# Habitat tags describe stable testbed characteristics only. They do not create weather,
# water values, populations, catches, or player condition effects.
const ZONES := {
	"elevated_camp": {
		"id": "elevated_camp", "terrain": "elevated dry ground", "exposure": "dry",
		"habitat_tags": ["dry_ground", "shelter_site", "overlook"], "species_ids": []
	},
	"sandy_shore": {
		"id": "sandy_shore", "terrain": "firm beach and dune track", "exposure": "splash zone",
		"habitat_tags": ["sand", "bank_access", "shoreline"], "species_ids": ["mullet", "atlantic_menhaden", "redfish"]
	},
	"marsh_edge": {
		"id": "marsh_edge", "terrain": "vegetated shoreline", "exposure": "ankle-deep wade",
		"habitat_tags": ["emergent_cover", "shallow_margin", "brackish_edge"], "species_ids": ["mullet", "redfish", "black_drum"]
	},
	"shallow_flat": {
		"id": "shallow_flat", "terrain": "firm open tidal flat", "exposure": "shin-deep wade",
		"habitat_tags": ["open_shallows", "warming_flat", "foraging_ground"], "species_ids": ["mullet", "atlantic_menhaden", "redfish", "black_drum"]
	},
	"tidal_channel": {
		"id": "tidal_channel", "terrain": "defined channel bank and launch", "exposure": "bank or boat",
		"habitat_tags": ["flow_corridor", "dropoff", "launch_access"], "species_ids": ["atlantic_menhaden", "redfish", "speckled_trout", "black_drum"]
	},
	"open_water": {
		"id": "open_water", "terrain": "open water", "exposure": "boat required",
		"habitat_tags": ["deep_water", "open_current", "pelagic_route"], "species_ids": ["atlantic_menhaden", "speckled_trout", "redfish"]
	}
}

# Every route is reciprocal. Durations are fixed Phase 2B fixtures so traversal can be
# tested before weather, tide/current, equipment, stamina, and pathfinding exist.
const ROUTES := [
	{"from":"elevated_camp", "to":"sandy_shore", "mode":"foot", "minutes":2, "requirement":"dry_path", "note":"Dune track"},
	{"from":"sandy_shore", "to":"elevated_camp", "mode":"foot", "minutes":2, "requirement":"dry_path", "note":"Dune track"},
	{"from":"sandy_shore", "to":"marsh_edge", "mode":"foot", "minutes":4, "requirement":"firm_bank", "note":"Firm shoreline"},
	{"from":"marsh_edge", "to":"sandy_shore", "mode":"foot", "minutes":4, "requirement":"firm_bank", "note":"Firm shoreline"},
	{"from":"sandy_shore", "to":"shallow_flat", "mode":"wade", "minutes":6, "requirement":"firm_flat", "note":"Marked firm-flat crossing"},
	{"from":"shallow_flat", "to":"sandy_shore", "mode":"wade", "minutes":6, "requirement":"firm_flat", "note":"Marked firm-flat crossing"},
	{"from":"marsh_edge", "to":"tidal_channel", "mode":"wade", "minutes":5, "requirement":"firm_margin", "note":"Firm marsh margin"},
	{"from":"tidal_channel", "to":"marsh_edge", "mode":"wade", "minutes":5, "requirement":"firm_margin", "note":"Firm marsh margin"},
	{"from":"shallow_flat", "to":"tidal_channel", "mode":"wade", "minutes":4, "requirement":"firm_flat", "note":"Marked firm-flat crossing"},
	{"from":"tidal_channel", "to":"shallow_flat", "mode":"wade", "minutes":4, "requirement":"firm_flat", "note":"Marked firm-flat crossing"},
	{"from":"tidal_channel", "to":"open_water", "mode":"boat", "minutes":12, "requirement":"channel_skiff", "note":"Test skiff staged at channel launch"},
	{"from":"open_water", "to":"tidal_channel", "mode":"boat", "minutes":12, "requirement":"channel_skiff", "note":"Return to channel launch"}
]

static func route(origin: String, destination: String) -> Dictionary:
	for entry in ROUTES:
		if entry["from"] == origin and entry["to"] == destination:
			return entry.duplicate(true)
	return {}

static func routes_from(origin: String) -> Array:
	var result: Array = []
	for entry in ROUTES:
		if entry["from"] == origin:
			result.append(entry.duplicate(true))
	return result

static func travel_result(origin: String, destination: String, travel: Dictionary) -> Dictionary:
	if not origin in ZONE_IDS or not destination in ZONE_IDS:
		return {"ok": false, "reason": "Unknown testbed zone."}
	if origin == destination:
		return {"ok": false, "reason": "You are already here."}
	var entry := route(origin, destination)
	if entry.is_empty():
		return {"ok": false, "reason": "No direct route from this zone. Follow one of the listed links."}
	if entry.requirement == "channel_skiff" and not bool(travel.get("channel_skiff_available", false)):
		return {"ok": false, "reason": "The channel skiff is unavailable."}
	return {"ok": true, "route": entry}

static func route_text(entry: Dictionary) -> String:
	return "%s · %d min · %s" % [String(entry.mode).capitalize(), int(entry.minutes), entry.note]

static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if ZONES.size() != 6 or ZONE_IDS.size() != 6:
		errors.append("Testbed requires exactly six zones.")
	for zone_id in ZONE_IDS:
		if not ZONES.has(zone_id):
			errors.append("Missing canonical zone: " + zone_id)
	for entry in ROUTES:
		if not entry is Dictionary or not entry.get("from") in ZONE_IDS or not entry.get("to") in ZONE_IDS:
			errors.append("Route has unknown endpoint.")
			continue
		if entry["from"] == entry["to"] or not entry.get("mode") in ["foot", "wade", "boat"] or int(entry.get("minutes", 0)) <= 0:
			errors.append("Route has invalid movement data.")
			continue
		var reverse := route(entry["to"], entry["from"])
		if reverse.is_empty() or reverse.mode != entry.mode or reverse.minutes != entry.minutes or reverse.requirement != entry.requirement:
			errors.append("Route is not reciprocal: %s → %s." % [entry["from"], entry["to"]])
	var reached: Dictionary = {}
	var pending: Array = ["sandy_shore"]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		if reached.has(current):
			continue
		reached[current] = true
		for entry in routes_from(current):
			pending.append(entry.to)
	if reached.size() != ZONE_IDS.size():
		errors.append("All six zones must be connected from sandy shore.")
	return errors
