extends RefCounted
## Versioned physical records. Commands must preserve identity and mass.

const VERSION := 7
const CAPACITY_G := 15000
const Ecology = preload("res://simulation/ecology.gd")
const Map = preload("res://simulation/testbed_map.gd")
const CONTAINERS := {"pack": 15000, "camp": 50000}
# Quantities are mL for water, kcal for legacy ration compatibility, units for
# wood/bait, and grams for unidentified historical fish. Mass is separate.
const DEFINITIONS := {"water_ml": [1, 1], "food_kcal": [1, 4], "firewood_units": [100, 1], "bait_units": [50, 1], "legacy_fish": [1, 1], "whole_fish": [1, 1], "cleaned_fish": [1, 1], "cooked_fish": [1, 1], "cut_bait": [1, 1], "test_rod": [300, 1], "test_spoon": [20, 1], "test_hook": [5, 1], "test_reel": [260, 1], "test_line": [50, 1]}
const TEST_EQUIPMENT := ["test_rod", "test_spoon", "test_hook", "test_reel", "test_line"]
const PRODUCTS := ["cleaned_fish", "cooked_fish", "cut_bait"]

static func use_item(record: Dictionary, id: String, action: String, zone: String) -> Dictionary:
	# Called on a private transaction copy by the kernel.
	if not record.entries.has(id):
		return {"ok": false, "message": "Select an existing item."}
	var e: Dictionary = record.entries[id]
	if e.container == "camp" and zone != "elevated_camp":
		return {"ok": false, "message": "Return to camp to access this item."}
	if action in ["clean", "bait", "cook"] and zone != "elevated_camp":
		return {"ok": false, "message": "Preparation requires the camp work area."}
	var energy := 0
	var minutes := 0
	var detail := ""
	if action == "clean" and e.kind in ["whole_fish", "legacy_fish"]:
		var initial := int(e.mass_g)
		e.mass_g = maxi(1, int(initial * 0.6))
		e.quantity = 1
		e.kind = "cleaned_fish"
		minutes = 10
		detail = "Cleaned %s: %d g fish, %d g processing waste removed." % [id, e.mass_g, initial - int(e.mass_g)]
	elif action == "bait" and e.kind in ["whole_fish", "legacy_fish", "cleaned_fish"]:
		e.kind = "cut_bait"
		e.quantity = 1
		minutes = 5
		detail = "Prepared %s as %d g cut bait. No food added." % [id, e.mass_g]
	elif action == "cook" and e.kind == "cleaned_fish":
		var fuel_id := ""
		var ids: Array = record.entries.keys()
		ids.sort()
		for candidate in ids:
			if record.entries[candidate].kind == "firewood_units":
				fuel_id = candidate
				break
		if fuel_id == "":
			return {"ok": false, "message": "Cooking requires one firewood unit."}
		var fuel: Dictionary = record.entries[fuel_id]
		fuel.quantity -= 1
		fuel.mass_g -= 100
		if fuel.quantity == 0:
			record.entries.erase(fuel_id)
		e.kind = "cooked_fish"
		minutes = 15
		detail = "Cooked %s using 100 g firewood at the test camp hearth." % id
	elif action == "eat" and e.kind == "cooked_fish":
		var serving := mini(250, int(e.mass_g))
		energy = maxi(1, int(serving / 2))
		e.mass_g -= serving
		if e.mass_g == 0:
			record.entries.erase(id)
		minutes = 5
		detail = "Ate %d g from %s." % [serving, id]
	else:
		return {"ok": false, "message": "That use is unavailable for this item. Clean raw fish before cooking; only cooked fish can be eaten."}
	return {"ok": true, "message": detail, "minutes": minutes, "energy": energy}

static func create() -> Dictionary:
	var record := migrate({"items": {"water_ml": 2000, "food_kcal": 4000, "firewood_units": 12, "bait_units": 0, "fish_food_g": 0}})
	return record

static func migrate(old: Dictionary) -> Dictionary:
	var record := {"version": VERSION, "next_id": 1, "entries": {}}
	for key in ["water_ml", "food_kcal", "firewood_units", "bait_units", "fish_food_g"]:
		var amount := int(old.items.get(key, 0))
		if amount > 0:
			_insert(record, "legacy_fish" if key == "fish_food_g" else key, amount, "pack", "", 0, "", -1)
	ensure_test_equipment(record)
	return record

static func ensure_test_equipment(record: Dictionary) -> void:
	for kind in TEST_EQUIPMENT:
		var found := false
		for entry in record.entries.values():
			if entry.kind == kind:
				found = true
				break
		if not found:
			var container := "pack" if total_weight_g(record) + _mass(kind, 1) <= CAPACITY_G else "camp"
			_insert(record, kind, 1, container, "", 0, "", -1)

static func carried_id(record: Dictionary, kind: String) -> String:
	var ids: Array = record.entries.keys()
	ids.sort()
	for id in ids:
		if record.entries[id].container == "pack" and record.entries[id].kind == kind:
			return id
	return ""

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

static func add_fish(record: Dictionary, species: String, mass_g: int, caught_ms: int, origin: String, condition: int = 1000) -> Dictionary:
	if species not in Ecology.SPECIES or origin not in Map.ZONE_IDS or not _integer(caught_ms, 0, 3153600000000) or not _integer(condition, 0, 1000) or mass_g <= 0:
		return {"ok": false, "message": "Invalid catch record."}
	if record.entries.size() >= 1000 or int(record.next_id) >= 2147483647 or total_weight_g(record) + mass_g > CAPACITY_G:
		return {"ok": false, "message": "Pack capacity reached."}
	var id := _insert(record, "whole_fish", mass_g, "pack", species, caught_ms, origin, condition)
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

static func validate(record: Variant, now_ms: int = 3153600000000, legacy_v3: bool = false, legacy_v4: bool = false, legacy_v5: bool = false, legacy_v6: bool = false) -> PackedStringArray:
	if not record is Dictionary or record.size() != 3 or not record.has_all(["version", "next_id", "entries"]):
		return PackedStringArray(["Invalid physical inventory fields."])
	var expected := 3 if legacy_v3 else (4 if legacy_v4 else (5 if legacy_v5 else (6 if legacy_v6 else VERSION)))
	if not _integer(record.version, expected, expected) or not _integer(record.next_id, 1, 2147483647) or not record.entries is Dictionary or record.entries.size() > 1000:
		return PackedStringArray(["Invalid physical inventory header."])
	var equipment_counts := {"test_rod": 0, "test_spoon": 0, "test_hook": 0, "test_reel": 0, "test_line": 0}
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
		if legacy_v3 and e.kind in PRODUCTS:
			return PackedStringArray(["Product is not supported by the old inventory version."])
		var unsupported_equipment := legacy_v3 or legacy_v4
		unsupported_equipment = unsupported_equipment or (legacy_v5 and e.kind in ["test_hook", "test_reel", "test_line"])
		unsupported_equipment = unsupported_equipment or (legacy_v6 and e.kind in ["test_reel", "test_line"])
		if e.kind in TEST_EQUIPMENT and (unsupported_equipment or e.quantity != 1):
			return PackedStringArray(["Invalid equipment record."])
		if e.kind in TEST_EQUIPMENT:
			equipment_counts[e.kind] += 1
		if e.kind in PRODUCTS:
			var known: bool = e.species in Ecology.SPECIES and e.origin in Map.ZONE_IDS and e.condition >= 0
			var unknown: bool = e.species == "" and e.origin == "" and e.caught_ms == 0 and e.condition == -1
			if e.quantity != 1 or not (known or unknown):
				return PackedStringArray(["Invalid processed fish provenance."])
		elif e.kind == "whole_fish":
			if e.quantity != 1 or e.species not in Ecology.SPECIES or e.origin not in Map.ZONE_IDS or e.condition < 0:
				return PackedStringArray(["Invalid individual fish provenance."])
		elif e.mass_g != _mass(e.kind, int(e.quantity)) or e.species != "" or e.origin != "" or e.caught_ms != 0 or e.condition != -1:
			return PackedStringArray(["Invalid supply mass or fabricated provenance."])
	for container in CONTAINERS:
		if total_weight_g(record, container) > int(CONTAINERS[container]):
			return PackedStringArray(["Container exceeds capacity."])
	var required_equipment: Array = []
	if legacy_v5:
		required_equipment = ["test_rod", "test_spoon"]
	elif legacy_v6:
		required_equipment = ["test_rod", "test_spoon", "test_hook"]
	elif not legacy_v3 and not legacy_v4:
		required_equipment = TEST_EQUIPMENT
	for kind in TEST_EQUIPMENT:
		var expected_count := 1 if kind in required_equipment else 0
		if int(equipment_counts[kind]) != expected_count:
			return PackedStringArray(["Inventory equipment set does not match its version: %s." % kind])
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
