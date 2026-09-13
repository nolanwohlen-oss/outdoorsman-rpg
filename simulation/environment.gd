extends RefCounted
## Synthetic coastal test forcing, NOT a forecast or real-world travel safety model.
## Fixed-point authoritative units; no engine RNG, wall clock, scenes, or frame delta.

const Map = preload("res://simulation/testbed_map.gd")
const VERSION := 1
const STEP_MS := 300000 # Five game minutes; all skipped ticks are integrated.
const DAY_MS := 86400000
const TIDE_MS := 43200000 # Deliberately fixed 12-hour laboratory tide.
const PROFILES := {
	"open_water": {"depth": 600, "salinity": 320, "clarity": 220, "flow": 60, "inertia": 72},
	"tidal_channel": {"depth": 240, "salinity": 250, "clarity": 140, "flow": 100, "inertia": 36},
	"marsh_edge": {"depth": 15, "salinity": 150, "clarity": 60, "flow": 25, "inertia": 12},
	"shallow_flat": {"depth": 20, "salinity": 220, "clarity": 100, "flow": 40, "inertia": 12},
	"sandy_shore": {"depth": 5, "salinity": 280, "clarity": 160, "flow": 10, "inertia": 18}
}

static func _div(numerator: int, denominator: int) -> int:
	@warning_ignore("integer_division")
	var result: int = numerator / denominator
	return result

static func tick_at(now_ms: int) -> int:
	return _div(now_ms, STEP_MS) * STEP_MS

static func _triangle(position: int, period: int) -> int:
	var phase := posmod(position, period)
	return _div(mini(phase, period - phase) * 2000, period)

static func weather_at(seed: int, at_ms: int) -> Dictionary:
	# A pressure trough crosses the region every 48 hours. Seed varies its timing
	# and strength. Cloud/rain/wind follow this one forcing, not independent rolls.
	var center := 18 * 3600000 + (seed % 121 - 60) * 60000
	var phase := posmod(at_ms - center + DAY_MS, 2 * DAY_MS) - DAY_MS
	var front := maxi(0, 1000 - _div(absi(phase) * 1000, 8 * 3600000))
	var strength := 90 + seed % 21
	var cloud := clampi(15 + _div(front * 85, 1000), 0, 100)
	var rain := maxi(0, _div((cloud - 65) * strength, 35)) # tenths mm/hour
	var solar := _triangle(at_ms - 3 * 3600000, DAY_MS) # warmest 15:00
	var air := 2100 + _div(solar * 800, 1000) - _div(front * 500, 1000)
	var state := "fair" if front == 0 else ("approaching" if phase < -3600000 else ("passing" if phase <= 3600000 else "clearing"))
	return {
		"air_temperature_centi_c": air,
		"wind_deci_mps": 30 + _div(front * strength * 14, 10000),
		"wind_from_degrees": 110 + _div((phase + 8 * 3600000) * 140, 16 * 3600000) if front > 0 else 110,
		"cloud_percent": cloud, "rain_deci_mm_hr": rain,
		"visibility_m": maxi(800, 16000 - rain * 100),
		"pressure_deci_hpa": 10180 - _div(front * strength, 1000),
		"front_state": state
	}

static func tide_at(seed: int, at_ms: int) -> Dictionary:
	var phase := posmod(at_ms - 6 * 3600000, TIDE_MS)
	var state := "flood" if phase < TIDE_MS / 2 else "ebb"
	if phase == 0:
		state = "low"
	elif phase == TIDE_MS / 2:
		state = "high"
	return {"phase": state, "height_cm": _div(_triangle(phase, TIDE_MS) * (80 + seed % 9), 1000)}

static func _water(zone: String, tide: Dictionary, weather: Dictionary, runoff: int, at_ms: int, temperature: int) -> Dictionary:
	if zone == "elevated_camp":
		return {"water_present": false} # Do not fabricate salinity/depth on dry ground.
	var p: Dictionary = PROFILES[zone]
	var flow := _triangle(at_ms - 6 * 3600000, TIDE_MS / 2)
	var current := _div(flow * (int(p.flow) + _div(weather.wind_deci_mps, 30) + _div(runoff, 50)), 1000)
	return {
		"water_present": true,
		"depth_cm": int(p.depth) + int(tide.height_cm) + _div(runoff, 20),
		"current_cm_s": current,
		"current_direction": "slack" if current == 0 else ("incoming" if tide.phase == "flood" else "outgoing"),
		"salinity_deci_ppt": maxi(0, int(p.salinity) + _div(tide.height_cm, 4) - _div(runoff, 8)),
		"clarity_cm": maxi(5, int(p.clarity) - _div(runoff, 8) - _div(weather.wind_deci_mps, 3)),
		"oxygen_centi_mg_l": clampi(850 - _div(temperature - 2000, 5) + current - _div(runoff, 10), 200, 1200),
		"temperature_centi_c": temperature
	}

static func create(seed: int, now_ms: int) -> Dictionary:
	var at_ms := tick_at(now_ms)
	var weather := weather_at(seed, at_ms)
	var tide := tide_at(seed, at_ms)
	var water: Dictionary = {}
	for zone in Map.ZONE_IDS:
		water[zone] = _water(zone, tide, weather, 0, at_ms, int(weather.air_temperature_centi_c))
	return {"version": VERSION, "initialized_at_ms": at_ms, "updated_at_ms": at_ms,
		"weather": weather, "tide": tide, "runoff_permille": 0, "water_by_zone": water}

static func advance_to(record: Dictionary, seed: int, target_ms: int) -> void:
	while int(record.updated_at_ms) + STEP_MS <= target_ms:
		var at_ms := int(record.updated_at_ms) + STEP_MS
		var weather := weather_at(seed, at_ms)
		var tide := tide_at(seed, at_ms)
		# Wetness/runoff survives the rain; drainage continues during fair weather.
		var runoff := clampi(int(record.runoff_permille) + _div(weather.rain_deci_mm_hr, 5) - 2, 0, 1000)
		for zone in PROFILES:
			var old_temp: int = record.water_by_zone[zone].temperature_centi_c
			var difference := int(weather.air_temperature_centi_c) - old_temp
			var change := _div(difference, int(PROFILES[zone].inertia))
			if change == 0 and difference != 0:
				change = 1 if difference > 0 else -1
			record.water_by_zone[zone] = _water(zone, tide, weather, runoff, at_ms, old_temp + change)
		record.weather = weather
		record.tide = tide
		record.runoff_permille = runoff
		record.updated_at_ms = at_ms

static func route_block(route: Dictionary, record: Dictionary) -> String:
	# These are test limits, not claims about safe real-world wading or boating.
	var weather: Dictionary = record.weather
	if route.mode == "foot":
		return "" # Elevated dry links remain an accessible camp test corridor.
	if route.mode == "wade":
		var base_depth := 15 if route.requirement == "firm_margin" else 20
		var depth := base_depth + int(record.tide.height_cm) + _div(record.runoff_permille, 20)
		var flow: int = record.water_by_zone.marsh_edge.current_cm_s
		if route.requirement == "firm_margin":
			flow = _div(record.water_by_zone.tidal_channel.current_cm_s, 2)
		else:
			flow = int(record.water_by_zone.shallow_flat.current_cm_s)
		if depth > 55:
			return "Wade crossing depth %d cm exceeds the 55 cm test limit." % depth
		if flow > 30:
			return "Wade crossing current %d cm/s exceeds the 30 cm/s test limit." % flow
		if int(weather.visibility_m) < 1000:
			return "Visibility is below the 1,000 m wading test limit."
	if route.mode == "boat":
		if int(weather.wind_deci_mps) > 120:
			return "Wind %.1f m/s exceeds the 12 m/s skiff test limit." % (float(weather.wind_deci_mps) / 10.0)
		if int(weather.visibility_m) < 3000:
			return "Visibility is below the 3,000 m skiff test limit."
	return ""

static func _keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and value == floor(value) and value >= minimum and value <= maximum

static func validate(record: Variant, seed: int, now_ms: int) -> PackedStringArray:
	if not _keys(record, ["version", "initialized_at_ms", "updated_at_ms", "weather", "tide", "runoff_permille", "water_by_zone"]):
		return PackedStringArray(["Environment has missing or unknown fields."])
	if not _integer(record.version, VERSION, VERSION) or not _integer(record.updated_at_ms, tick_at(now_ms), tick_at(now_ms)) or not _integer(record.initialized_at_ms, 21600000, tick_at(now_ms)) or int(record.initialized_at_ms) % STEP_MS != 0 or not _integer(record.runoff_permille, 0, 1000):
		return PackedStringArray(["Invalid environment version, tick, or runoff."])
	var expected_weather := weather_at(seed, int(record.updated_at_ms))
	var expected_tide := tide_at(seed, int(record.updated_at_ms))
	# Strict primitive checks prevent JSON booleans being accepted as numbers.
	for pair in [[record.weather, expected_weather], [record.tide, expected_tide]]:
		if not _keys(pair[0], pair[1].keys()):
			return PackedStringArray(["Invalid weather or tide fields."])
		for key in pair[1]:
			var value: Variant = pair[0][key]
			var expected: Variant = pair[1][key]
			if typeof(expected) == TYPE_INT:
				if not _integer(value, expected, expected):
					return PackedStringArray(["Weather or tide does not match its seed and tick."])
			elif not value is String or value != expected:
				return PackedStringArray(["Invalid front or tide phase."])
	if not _keys(record.water_by_zone, Map.ZONE_IDS):
		return PackedStringArray(["Water records must cover exactly six zones."])
	for zone in Map.ZONE_IDS:
		var water: Variant = record.water_by_zone[zone]
		if zone == "elevated_camp":
			if not _keys(water, ["water_present"]) or typeof(water.water_present) != TYPE_BOOL or water.water_present:
				return PackedStringArray(["Camp must remain dry."])
			continue
		if not water is Dictionary or not _integer(water.get("temperature_centi_c"), 1500, 3500):
			return PackedStringArray(["Invalid water temperature."])
		var expected := _water(zone, expected_tide, expected_weather, int(record.runoff_permille), int(record.updated_at_ms), int(water.temperature_centi_c))
		if not _keys(water, expected.keys()):
			return PackedStringArray(["Invalid water fields."])
		for key in expected:
			if typeof(expected[key]) == TYPE_INT:
				if not _integer(water[key], expected[key], expected[key]):
					return PackedStringArray(["Invalid water units or derived state."])
			elif typeof(water[key]) != typeof(expected[key]) or water[key] != expected[key]:
				return PackedStringArray(["Invalid water presence or current direction."])
	return PackedStringArray()

static func normalized(value: Variant) -> Variant:
	# JSON decodes numbers as floats. Normalize before any fixed-point arithmetic.
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = normalized(value[key])
		return result
	return int(value) if typeof(value) == TYPE_FLOAT else value
