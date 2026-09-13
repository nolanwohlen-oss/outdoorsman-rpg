extends SceneTree
## Phase 1 gates: catalog integrity, graph reachability, and a live scene launch.

const Catalog = preload("res://scripts/catalog.gd")
var failures := 0
var checks := 0

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, explanation: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(explanation)

func _run() -> void:
	var catalog := Catalog.read()
	check(Catalog.validate(catalog).is_empty(), "Starter catalog must validate.")
	if catalog.is_empty():
		quit(1)
		return
	check(catalog.zones.size() == 6, "Approved map contains six zones.")
	check(catalog.species.size() == 5, "Approved catalog contains five species.")
	check(catalog.layers.size() == 9, "Roadmap contains nine simulation layers.")
	var lookup: Dictionary = {}
	for zone in catalog.zones:
		lookup[zone.id] = zone
	var visited: Dictionary = {}
	var remaining: Array = ["sandy_shore"]
	while not remaining.is_empty():
		var current: String = remaining.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		for neighbor in lookup[current].neighbors:
			remaining.append(neighbor)
	check(visited.size() == 6, "Every zone must be reachable from shore.")
	var invalid := catalog.duplicate(true)
	invalid.zones[0].neighbors.append("missing_zone")
	check(not Catalog.validate(invalid).is_empty(), "Unknown connections must be rejected.")
	invalid = catalog.duplicate(true)
	invalid.species.append(invalid.species[0].duplicate())
	check(not Catalog.validate(invalid).is_empty(), "Duplicate IDs must be rejected.")
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene must load.")
	if scene == null:
		quit(1)
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	check(app.zone_buttons.size() == 6, "All zone controls must render.")
	check(app.tabs.get_tab_count() == 3, "Map, Layers and Log tabs must be available.")
	for zone in catalog.zones:
		app.zone_buttons[zone.id].pressed.emit()
		check(app.selected_zone_id == zone.id and app.inspector_title.text == zone.name, "Zone tap must update its inspector.")
	app.seed_input.get_line_edit().text = "42"
	app._set_seed()
	check(app.seed_value == 42, "Seed control must apply the entered value.")
	check(app.event_log.text.contains("42"), "Seed change must appear in the event log.")
	app.queue_free()
	await process_frame
	print("Phase 1 checks: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)
