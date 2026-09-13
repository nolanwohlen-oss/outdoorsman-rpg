extends RefCounted
## Phase 2D population ledger. Counts are testbed units, not real surveys.

const Map = preload("res://simulation/testbed_map.gd")
const STEP_MS := 900000 # 15 game minutes.
const VERSION := 1
const SPECIES := ["mullet", "atlantic_menhaden", "redfish", "speckled_trout", "black_drum"]
const CAPACITY := {
	"mullet": {"sandy_shore": 90, "marsh_edge": 110, "shallow_flat": 80, "tidal_channel": 60, "open_water": 30},
	"atlantic_menhaden": {"sandy_shore": 70, "marsh_edge": 40, "shallow_flat": 90, "tidal_channel": 120, "open_water": 180},
	"redfish": {"sandy_shore": 35, "marsh_edge": 70, "shallow_flat": 55, "tidal_channel": 80, "open_water": 25},
	"speckled_trout": {"sandy_shore": 0, "marsh_edge": 20, "shallow_flat": 25, "tidal_channel": 70, "open_water": 90},
	"black_drum": {"sandy_shore": 15, "marsh_edge": 65, "shallow_flat": 55, "tidal_channel": 85, "open_water": 20}
}

static func _div(a: int, b: int) -> int:
	@warning_ignore("integer_division")
	return a / b

static func _blank_populations() -> Dictionary:
	var result: Dictionary = {}
	for species in SPECIES:
		result[species] = {}
		for zone in Map.ZONE_IDS:
			result[species][zone] = 0
	return result

static func create(seed: int, now_ms: int) -> Dictionary:
	var populations := _blank_populations()
	for species in SPECIES:
		for zone in CAPACITY[species]:
			var cap: int = CAPACITY[species][zone]
			populations[species][zone] = _div(cap * (55 + ((seed + zone.length() * 17 + species.length() * 13) % 31)), 100)
	return {"version": VERSION, "initialized_at_ms": now_ms - posmod(now_ms, STEP_MS), "updated_at_ms": now_ms - posmod(now_ms, STEP_MS), "populations": populations, "births": 0, "deaths": 0, "moves": 0}

static func _food_factor(species: String, zone: String, environment: Dictionary) -> int:
	if zone == "elevated_camp":
		return 0
	var water: Dictionary = environment.water_by_zone[zone]
	var oxygen: int = int(water.oxygen_centi_mg_l)
	var clarity: int = int(water.clarity_cm)
	var factor := clampi(_div(oxygen, 10) + _div(clarity, 2), 0, 100)
	if species == "speckled_trout":
		factor += 10 if int(water.temperature_centi_c) < 2700 else -10
	elif species == "redfish" or species == "black_drum":
		factor += 8 if int(water.salinity_deci_ppt) >= 150 else -8
	return clampi(factor, 0, 100)

static func advance_to(record: Dictionary, seed: int, target_ms: int, environment: Dictionary) -> void:
	while int(record.updated_at_ms) + STEP_MS <= target_ms:
		var at_ms := int(record.updated_at_ms) + STEP_MS
		var moved := 0
		for species in SPECIES:
			# Reproduction/death is bounded by local capacity and food; integer-only.
			for zone in CAPACITY[species]:
				var count: int = record.populations[species][zone]
				var cap: int = CAPACITY[species][zone]
				var food := _food_factor(species, zone, environment)
				var births := _div(count * food, 10000)
				var deaths := _div(count * (100 - food), 25000)
				record.populations[species][zone] = clampi(count + births - deaths, 0, cap)
				record.births += births
				record.deaths += deaths
			# One deterministic school shift per tick, never into an unlisted habitat.
			var source_index := posmod(seed + int(at_ms / STEP_MS) + species.length(), 5)
			var source: String = Map.ZONE_IDS[source_index]
			if not CAPACITY[species].has(source) or record.populations[species][source] <= 0:
				continue
			for route in Map.routes_from(source):
				var destination: String = route.to
				if CAPACITY[species].get(destination, 0) > 0 and _food_factor(species, destination, environment) > _food_factor(species, source, environment) + 8:
					var moved_count := maxi(1, _div(record.populations[species][source], 100))
					record.populations[species][source] -= moved_count
					record.populations[species][destination] = mini(int(CAPACITY[species][destination]), int(record.populations[species][destination]) + moved_count)
					record.moves += moved_count
					moved += moved_count
					break
		record.updated_at_ms = at_ms

static func total(record: Dictionary, species: String) -> int:
	var sum := 0
	for count in record.populations[species].values():
		sum += int(count)
	return sum

static func validate(record: Variant, seed: int, now_ms: int) -> PackedStringArray:
	if not record is Dictionary or record.size() != 7 or not record.has_all(["version", "initialized_at_ms", "updated_at_ms", "populations", "births", "deaths", "moves"]):
		return PackedStringArray(["Ecology has missing or unknown fields."])
	var tick := now_ms - posmod(now_ms, STEP_MS)
	for field in ["version", "initialized_at_ms", "updated_at_ms", "births", "deaths", "moves"]:
		if typeof(record[field]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(record[field])) or record[field] != floor(record[field]) or int(record[field]) < 0:
			return PackedStringArray(["Invalid ecology counter or timestamp."])
	if int(record.version) != VERSION or int(record.updated_at_ms) != tick or int(record.initialized_at_ms) < 21600000 or int(record.initialized_at_ms) > tick or int(record.initialized_at_ms) % STEP_MS != 0:
		return PackedStringArray(["Invalid ecology update boundary."])
	if not record.populations is Dictionary or record.populations.size() != SPECIES.size():
		return PackedStringArray(["Ecology must contain exactly five species."])
	for species in SPECIES:
		if not record.populations.has(species) or not record.populations[species] is Dictionary or record.populations[species].size() != 6:
			return PackedStringArray(["Ecology species zones are incomplete."])
		for zone in Map.ZONE_IDS:
			var value: Variant = record.populations[species].get(zone)
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or value != floor(value) or int(value) < 0 or int(value) > int(CAPACITY[species].get(zone, 0)):
				return PackedStringArray(["Ecology count exceeds capacity or has invalid units."])
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
