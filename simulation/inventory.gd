extends RefCounted
## Phase 2E inventory contract. Quantities are test units until item actions exist.

const VERSION := 1
const ITEMS := {"water_ml": {"min": 0, "max": 12000}, "food_kcal": {"min": 0, "max": 24000}, "firewood_units": {"min": 0, "max": 100}, "bait_units": {"min": 0, "max": 100}}

static func create() -> Dictionary:
	return {"version": VERSION, "items": {"water_ml": 2000, "food_kcal": 4000, "firewood_units": 12, "bait_units": 0}}

static func validate(record: Variant) -> PackedStringArray:
	if not record is Dictionary or record.size() != 2 or not record.has_all(["version", "items"]):
		return PackedStringArray(["Inventory has missing or unknown fields."])
	if int(record.version) != VERSION or not record.items is Dictionary or record.items.size() != ITEMS.size():
		return PackedStringArray(["Invalid inventory version or item set."])
	for item in ITEMS:
		var value: Variant = record.items.get(item)
		var limits: Dictionary = ITEMS[item]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value != floor(value) or int(value) < limits.min or int(value) > limits.max:
			return PackedStringArray(["Invalid inventory quantity."])
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
