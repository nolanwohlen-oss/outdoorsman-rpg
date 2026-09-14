extends RefCounted
## Phase 2H physical inventory contract with bounded items and carry weight.

const VERSION := 2
const CAPACITY_G := 15000
const ITEMS := {"water_ml": {"min": 0, "max": 12000, "grams_per_unit": 1}, "food_kcal": {"min": 0, "max": 24000, "grams_per_unit": 1}, "firewood_units": {"min": 0, "max": 100, "grams_per_unit": 100}, "bait_units": {"min": 0, "max": 100, "grams_per_unit": 50}, "fish_food_g": {"min": 0, "max": 10000, "grams_per_unit": 1}}

static func create() -> Dictionary:
	return {"version": VERSION, "capacity_g": CAPACITY_G, "items": {"water_ml": 2000, "food_kcal": 4000, "firewood_units": 12, "bait_units": 0, "fish_food_g": 0}}

static func total_weight_g(record: Dictionary) -> int:
	var total := 0
	for item in ITEMS:
		total += int(record.items.get(item, 0)) * int(ITEMS[item].grams_per_unit)
	return total

static func add(record: Dictionary, item: String, quantity: int) -> Dictionary:
	if not ITEMS.has(item) or quantity <= 0:
		return {"ok": false, "message": "Unknown item or quantity."}
	var next := int(record.items[item]) + quantity
	if next > int(ITEMS[item].max) or total_weight_g(record) + quantity * int(ITEMS[item].grams_per_unit) > int(record.capacity_g):
		return {"ok": false, "message": "Inventory capacity or item limit reached."}
	record.items[item] = next
	return {"ok": true}

static func remove(record: Dictionary, item: String, quantity: int) -> Dictionary:
	if not ITEMS.has(item) or quantity <= 0 or int(record.items.get(item, 0)) < quantity:
		return {"ok": false, "message": "Item quantity unavailable."}
	record.items[item] = int(record.items[item]) - quantity
	return {"ok": true}

static func validate(record: Variant) -> PackedStringArray:
	if not record is Dictionary or record.size() != 3 or not record.has_all(["version", "capacity_g", "items"]):
		return PackedStringArray(["Inventory has missing or unknown fields."])
	if int(record.version) != VERSION or int(record.capacity_g) != CAPACITY_G or not record.items is Dictionary or record.items.size() != ITEMS.size():
		return PackedStringArray(["Invalid inventory version, capacity or item set."])
	for item in ITEMS:
		var value: Variant = record.items.get(item)
		var limits: Dictionary = ITEMS[item]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value != floor(value) or int(value) < limits.min or int(value) > limits.max:
			return PackedStringArray(["Invalid inventory quantity."])
	if total_weight_g(record) > int(record.capacity_g):
		return PackedStringArray(["Inventory exceeds carry capacity."])
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
