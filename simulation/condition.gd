extends RefCounted
## Phase 2E player condition ledger. Integer test units; no medical model.

const STEP_MS := 900000 # 15 game minutes.
const VERSION := 1
const MAX_VALUE := 1000

static func create(now_ms: int) -> Dictionary:
	var boundary := now_ms - posmod(now_ms, STEP_MS)
	return {"version": VERSION, "initialized_at_ms": boundary, "updated_at_ms": boundary, "hydration": 1000, "energy": 1000, "exposure": 0, "sleep_debt": 0, "health": 1000}

static func advance_to(record: Dictionary, target_ms: int, zone: String, environment: Dictionary) -> void:
	while int(record.updated_at_ms) + STEP_MS <= target_ms:
		var at_ms := int(record.updated_at_ms) + STEP_MS
		var sheltered := zone == "elevated_camp"
		var rain := int(environment.weather.rain_deci_mm_hr)
		var wind := int(environment.weather.wind_deci_mps)
		record.hydration = maxi(0, int(record.hydration) - (1 if sheltered else 2))
		record.energy = maxi(0, int(record.energy) - (1 if sheltered else 2))
		record.sleep_debt = mini(MAX_VALUE, int(record.sleep_debt) + (1 if not sheltered else 0))
		var exposure_change := -2 if sheltered else 1
		if rain > 0:
			exposure_change += 3 if not sheltered else 1
		if wind >= 80:
			exposure_change += 1
		record.exposure = clampi(int(record.exposure) + exposure_change, 0, MAX_VALUE)
		if sheltered and int(record.exposure) < 250:
			record.health = mini(MAX_VALUE, int(record.health) + 1)
		elif int(record.hydration) < 200 or int(record.exposure) > 800:
			record.health = maxi(0, int(record.health) - 1)
		record.updated_at_ms = at_ms

static func validate(record: Variant, now_ms: int) -> PackedStringArray:
	var fields := ["version", "initialized_at_ms", "updated_at_ms", "hydration", "energy", "exposure", "sleep_debt", "health"]
	if not record is Dictionary or record.size() != fields.size() or not record.has_all(fields):
		return PackedStringArray(["Condition has missing or unknown fields."])
	var tick := now_ms - posmod(now_ms, STEP_MS)
	if int(record.version) != VERSION or int(record.initialized_at_ms) < 21600000 or int(record.initialized_at_ms) > tick or int(record.updated_at_ms) != tick or int(record.initialized_at_ms) % STEP_MS != 0:
		return PackedStringArray(["Invalid condition update boundary."])
	for field in ["hydration", "energy", "exposure", "sleep_debt", "health"]:
		if typeof(record[field]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(record[field])) or record[field] != floor(record[field]) or int(record[field]) < 0 or int(record[field]) > MAX_VALUE:
			return PackedStringArray(["Invalid condition value."])
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
