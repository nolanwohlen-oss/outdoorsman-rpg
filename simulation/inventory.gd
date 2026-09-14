extends RefCounted
## Versioned physical records. Commands must preserve identity and mass.

const VERSION := 3
const CAPACITY_G := 15000
const Ecology = preload("res://simulation/ecology.gd")
const Map = preload("res://simulation/testbed_map.gd")
const CONTAINERS := {"pack": 15000, "camp": 50000}
# Quantities are mL for water, kcal for legacy ration compatibility, units for
# wood/bait, and grams for unidentified historical fish. Mass is separate.
const DEFINITIONS := {"water_ml": [1, 1], "food_kcal": [1, 4], "firewood_units": [100, 1], "bait_units": [50, 1], "legacy_fish": [1, 1], "whole_fish": [1, 1]}

static func create() -> Dictionary:
	return migrate({"items": {"water_ml": 2000, "food_kcal": 4000, "firewood_units": 12, "bait_units": 0, "fish_food_g": 0}})

static func migrate(old: Dictionary) -> Dictionary:
	var record := {"version": VERSION, "next_id": 1, "entries": {}}
	for key in ["water_ml", "food_kcal", "firewood_units", "bait_units", "fish_food_g"]:
		var amount := int(old.items.get(key, 0))
		if amount > 0:
			_insert(record, "legacy_fish" if key == "fish_food_g" else key, amount, "pack", "", 0, "", -1)
	return record

static func _mass(kind: String, quantity: int) -> int:
	return int(ceil(float(quantity * int(DEFINITIONS[kind][0])) / int(DEFINITIONS[kind][1])))

static func _insert(record: Dictionary, kind: String, quantity: int, container: String, species: String, caught_ms: int, origin: String, condition: int) -> String:
	var id := "item_%d" % int(record.next_id)
	record.next_id += 1
	record.entries[id] = {"kind": kind, "quantity": quantity, "mass_g": _mass(kind, quantity), "container": container, "owner": "player", "condition": condition, "species": species, "caught_ms": caught_ms, "origin": origin}
	return id

static func total_weight_g(record: Dictionary, container: String = "pack") -> int:
	var total := 0
	for entry in record.entries.values():
		if entry.container == container:
			total += int(entry.mass_g)
	return total

static func quantity(record: Dictionary, kind: String, container: String = "pack") -> int:
	var total := 0
	for entry in record.entries.values():
		if entry.container == container:
			if kind == "fish_food_g" and entry.kind in ["whole_fish", "legacy_fish"]:
				total += int(entry.mass_g)
			elif entry.kind == kind:
				total += int(entry.quantity)
	return total

static func add_fish(record: Dictionary, species: String, mass_g: int, caught_ms: int, origin: String) -> Dictionary:
	if species not in Ecology.SPECIES or origin not in Map.ZONE_IDS or not _integer(caught_ms, 0, 3153600000000) or mass_g <= 0:
		return {"ok": false, "message": "Invalid catch record."}
	if record.entries.size() >= 1000 or int(record.next_id) >= 2147483647 or total_weight_g(record) + mass_g > CAPACITY_G:
		return {"ok": false, "message": "Pack capacity reached."}
	var id := _insert(record, "whole_fish", mass_g, "pack", species, caught_ms, origin, 1000)
	# A whole fish is an individual, not a stack of grams.
	record.entries[id].quantity = 1
	return {"ok": true, "id": id}

static func transfer(record: Dictionary, id: String, destination: String, zone: String) -> Dictionary:
	if zone != "elevated_camp":
		return {"ok": false, "message": "Camp storage is only accessible at elevated camp."}
	if not record.entries.has(id) or not CONTAINERS.has(destination):
		return {"ok": false, "message": "Unknown item or container."}
	var entry: Dictionary = record.entries[id]
	if entry.container == destination:
		return {"ok": false, "message": "Item is already in that container."}
	if total_weight_g(record, destination) + int(entry.mass_g) > int(CONTAINERS[destination]):
		return {"ok": false, "message": "Destination has insufficient capacity."}
	entry.container = destination
	return {"ok": true, "message": "%s moved to %s." % [id, destination]}

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value == floor(value) and value >= minimum and value <= maximum

static func validate(record: Variant, now_ms: int = 3153600000000) -> PackedStringArray:
	if not record is Dictionary or record.size() != 3 or not record.has_all(["version", "next_id", "entries"]):
		return PackedStringArray(["Invalid physical inventory fields."])
	if not _integer(record.version, VERSION, VERSION) or not _integer(record.next_id, 1, 2147483647) or not record.entries is Dictionary or record.entries.size() > 1000:
		return PackedStringArray(["Invalid physical inventory header."])
	for id in record.entries:
		if not id is String or not id.begins_with("item_") or not id.trim_prefix("item_").is_valid_int():
			return PackedStringArray(["Invalid item identity."])
		var serial := int(id.trim_prefix("item_"))
		if serial < 1 or serial >= int(record.next_id) or id != "item_%d" % serial:
			return PackedStringArray(["Item identity exceeds sequence or is noncanonical."])
		var e: Variant = record.entries[id]
		if not e is Dictionary or e.size() != 9 or not e.has_all(["kind", "quantity", "mass_g", "container", "owner", "condition", "species", "caught_ms", "origin"]):
			return PackedStringArray(["Invalid item fields."])
		if not e.kind is String or not DEFINITIONS.has(e.kind) or not e.container is String or not CONTAINERS.has(e.container) or e.owner != "player":
			return PackedStringArray(["Invalid item definition or location."])
		if not _integer(e.quantity, 1, 200000) or not _integer(e.mass_g, 1, 65000) or not _integer(e.condition, -1, 1000) or not _integer(e.caught_ms, 0, now_ms):
			return PackedStringArray(["Invalid item quantity, mass, condition or time."])
		if e.kind == "whole_fish":
			if e.quantity != 1 or e.species not in Ecology.SPECIES or e.origin not in Map.ZONE_IDS or e.condition < 0:
				return PackedStringArray(["Invalid individual fish provenance."])
		elif e.mass_g != _mass(e.kind, int(e.quantity)) or e.species != "" or e.origin != "" or e.caught_ms != 0 or e.condition != -1:
			return PackedStringArray(["Invalid supply mass or fabricated provenance."])
	for container in CONTAINERS:
		if total_weight_g(record, container) > int(CONTAINERS[container]):
			return PackedStringArray(["Container exceeds capacity."])
	return PackedStringArray()
const ITEMS := {"water_ml": {"min": 0, "max": 12000, "grams_per_unit": 1}, "food_kcal": {"min": 0, "max": 24000, "grams_per_unit": 1}, "firewood_units": {"min": 0, "max": 100, "grams_per_unit": 100}, "bait_units": {"min": 0, "max": 100, "grams_per_unit": 50}, "fish_food_g": {"min": 0, "max": 10000, "grams_per_unit": 1}}

static func old_weight_g(record: Dictionary) -> int:
	var total := 0
	for item in ITEMS:
		total += int(record.items.get(item, 0)) * int(ITEMS[item].grams_per_unit)
	return total

static func validate_v2(record: Variant) -> PackedStringArray:
	if not record is Dictionary or record.size() != 3 or not record.has_all(["version", "capacity_g", "items"]):
		return PackedStringArray(["Inventory has missing or unknown fields."])
	for field in ["version", "capacity_g"]:
		if typeof(record[field]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(record[field])) or record[field] != floor(record[field]):
			return PackedStringArray(["Invalid inventory numeric field."])
	if int(record.version) != 2 or int(record.capacity_g) != CAPACITY_G or not record.items is Dictionary or record.items.size() != ITEMS.size():
		return PackedStringArray(["Invalid inventory version, capacity or item set."])
	for item in ITEMS:
		var value: Variant = record.items.get(item)
		var limits: Dictionary = ITEMS[item]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value != floor(value) or int(value) < limits.min or int(value) > limits.max:
			return PackedStringArray(["Invalid inventory quantity."])
	if old_weight_g(record) > int(record.capacity_g):
		return PackedStringArray(["Inventory exceeds carry capacity."])
	return PackedStringArray()

static func validate_legacy(record: Variant) -> PackedStringArray:
	if not record is Dictionary or record.size() != 2 or not record.has_all(["version", "items"]):
		return PackedStringArray(["Invalid legacy inventory fields."])
	if typeof(record.version) not in [TYPE_INT, TYPE_FLOAT] or record.version != 1 or not record.items is Dictionary or record.items.size() != 4:
		return PackedStringArray(["Invalid legacy inventory version or items."])
	for item in ["water_ml", "food_kcal", "firewood_units", "bait_units"]:
		var value: Variant = record.items.get(item)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value != floor(value) or value < 0 or value > ITEMS[item].max:
			return PackedStringArray(["Invalid legacy inventory quantity."])
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
