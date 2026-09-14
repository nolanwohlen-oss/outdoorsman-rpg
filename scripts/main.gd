extends Control
## Touch UI and lifecycle adapter. The kernel owns all gameplay mutations.

const Catalog = preload("res://scripts/catalog.gd")
const Kernel = preload("res://simulation/kernel.gd")
const Session = preload("res://simulation/session.gd")
const SaveStore = preload("res://simulation/save_store.gd")
const Map = preload("res://simulation/testbed_map.gd")
const Ecology = preload("res://simulation/ecology.gd")
const TEXT := Color("e8eee2")
const MUTED := Color("a8bcb3")
const ACCENT := Color("d8bd83")

# Tests/captures inject their own directory before entering the scene tree.
var save_directory: String = SaveStore.DEFAULT_DIRECTORY
var catalog: Dictionary
var kernel: Kernel
var session: Session
var saves: SaveStore
var selected_zone_id := "sandy_shore"
var zone_buttons: Dictionary = {}
var inspector_title: Label
var inspector_body: Label
var move_button: Button
var trip_button: Button
var route_label: Label
var event_log: RichTextLabel
var seed_input: SpinBox
var seed_value := 13092026
var tabs: TabContainer
var clock_label: Label
var calendar_label: Label
var location_label: Label
var run_button: Button
var wait_buttons: Array[Button] = []
var safe_wait_label: Label
var save_label: Label
var scheduler_label: Label
var status_label: Label
var new_world_dialog: ConfirmationDialog
var save_blocked := false
var autosave_game_ms: int = 0
var last_display_second: int = -1
var last_environment_tick: int = -1
var environment_stamp: Label
var weather_label: Label
var water_label: Label
var ecology_label: Label
var environment_zone: OptionButton
var condition_label: Label
var inventory_label: Label

func _ready() -> void:
	theme = _theme()
	catalog = Catalog.read()
	var problems := Catalog.validate(catalog)
	if not problems.is_empty():
		var error_label := _label("Catalog error\n" + "\n".join(problems), 28, ACCENT)
		add_child(error_label)
		push_error(error_label.text)
		return
	kernel = Kernel.new(int(catalog.default_seed))
	session = Session.new(kernel)
	saves = SaveStore.new(save_directory)
	get_tree().auto_accept_quit = false
	_build_interface()
	var initial_slot := "autosave" if saves.exists("autosave") else "manual"
	if saves.exists(initial_slot):
		var loaded := saves.load_slot(initial_slot)
		if loaded.ok:
			kernel.restore(loaded.record)
			_status(loaded.get("message", "Saved world restored. Clock is paused."))
			if loaded.get("migrated", false):
				_autosave()
		else:
			save_blocked = true
			_status("Load failed: " + loaded.message + " Use New world to reset autosave.")
	else:
		_status("New world at sandy shore. Tap Run or travel to camp.")
	seed_value = kernel.world.seed
	seed_input.value = seed_value
	selected_zone_id = kernel.world.player_zone
	_refresh()
	if not save_blocked and not saves.exists("autosave"):
		_autosave()

func _process(_delta: float) -> void:
	if session == null:
		return
	var prior_events := kernel.world.events_processed
	var result := session.sample(Time.get_ticks_usec())
	if not result.ok:
		_status(result.message)
		_refresh()
	autosave_game_ms += int(result.get("advanced_ms", 0))
	if int(kernel.world.game_time_ms / 1000) != last_display_second:
		_refresh_clock()
		# A departure window can close BEFORE the next environmental tick when
		# arrival reaches that tick. Keep the preview in sync with displayed time.
		select_zone(selected_zone_id)
	if kernel.world.events_processed != prior_events:
		_refresh_log()
	if int(kernel.world.environment.updated_at_ms) != last_environment_tick:
		select_zone(selected_zone_id)
	if autosave_game_ms >= 180000: # 30 active real seconds at 6:1.
		_autosave()

func _notification(what: int) -> void:
	if session == null:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_background("focus")
		NOTIFICATION_APPLICATION_PAUSED:
			_background("suspend")
		NOTIFICATION_APPLICATION_FOCUS_IN:
			session.resume("focus")
			_refresh()
		NOTIFICATION_APPLICATION_RESUMED:
			session.resume("suspend")
			_refresh()
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			session.set_running(false)
			_autosave()
			get_tree().quit()

func _background(reason: String) -> void:
	session.suspend(reason)
	_autosave()
	_status("Paused in background. Tap Run when ready.")
	_refresh()

func _theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 24
	result.set_color("font_color", "Label", TEXT)
	result.set_color("default_color", "RichTextLabel", MUTED)
	for state in ["normal", "hover", "pressed", "focus"]:
		result.set_stylebox(state, "Button", _panel(Color("1b3335"), Color("46615a")))
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_disabled_color", "Button", Color("72867e"))
	result.set_color("font_pressed_color", "Button", ACCENT)
	result.set_color("font_hover_color", "Button", TEXT)
	result.set_constant("h_separation", "TabBar", 18)
	result.set_font_size("font_size", "TabBar", 24)
	result.set_color("font_selected_color", "TabBar", ACCENT)
	result.set_color("font_unselected_color", "TabBar", MUTED)
	result.set_stylebox("panel", "TabContainer", _panel(Color("101f23")))
	result.set_stylebox("tab_selected", "TabBar", _panel(Color("203636")))
	result.set_stylebox("tab_unselected", "TabBar", _panel(Color("101f23")))
	return result

func _panel(color: Color, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _label(value: String, font_size := 24, color := TEXT) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _column(parent: Node, separation := 14) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 64
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	return row

func _scroll_tab(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(scroll)
	return _column(scroll, 18)

func _build_interface() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var layout := _column(margin, 8)
	layout.add_child(_label("OUTDOORSMAN", 34))
	layout.add_child(_label("SYSTEMS LAB  /  PHASE 2C", 20, ACCENT))
	clock_label = _label("", 30)
	calendar_label = _label("", 21, MUTED)
	location_label = _label("", 23, ACCENT)
	layout.add_child(clock_label)
	layout.add_child(calendar_label)
	layout.add_child(location_label)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	_build_clock(_scroll_tab("Clock"))
	_build_map(_scroll_tab("Map"))
	_build_environment(_scroll_tab("Env"))
	_build_layers(_scroll_tab("Layers"))
	var log_column := _scroll_tab("Log")
	log_column.add_child(_label("World event log", 28, ACCENT))
	log_column.add_child(_label("Latest 200 events, preserved in saves. Times are game time.", 21, MUTED))
	event_log = RichTextLabel.new()
	event_log.fit_content = true
	event_log.custom_minimum_size.y = 120
	event_log.add_theme_font_size_override("normal_font_size", 22)
	log_column.add_child(event_log)
	status_label = _label("", 21, ACCENT)
	status_label.max_lines_visible = 4
	layout.add_child(status_label)
	var build := "v0.6.0 · local build"
	if FileAccess.file_exists("res://config/build_info.json"):
		var info = JSON.parse_string(FileAccess.get_file_as_string("res://config/build_info.json"))
		if info is Dictionary:
			build = "v0.6.0 · build %s · %s" % [str(info.get("number", "local")).trim_suffix(".0"), info.get("commit", "unknown")]
	layout.add_child(_label(build, 18, MUTED))
	new_world_dialog = ConfirmationDialog.new()
	new_world_dialog.title = "Start a new test world?"
	new_world_dialog.dialog_text = "Replace current progress? Your manual save stays."
	new_world_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_world_dialog.get_label().custom_minimum_size = Vector2(520, 72)
	new_world_dialog.get_ok_button().text = "New world"
	new_world_dialog.confirmed.connect(_new_world)
	add_child(new_world_dialog)

func _build_clock(column: VBoxContainer) -> void:
	column.add_child(_label("1 real minute = 6 game minutes. The world stays paused while closed or in the background.", 22, MUTED))
	run_button = _button(column, "Run clock", _toggle_running)
	var row := _row(column)
	_button(row, "Observe", _observe)
	_button(row, "Go to camp\n2 min", _move_to.bind("elevated_camp"))
	column.add_child(HSeparator.new())
	column.add_child(_label("Fishing test actions", 26, ACCENT))
	_button(column, "Prepare rig", _fish_rig)
	_button(column, "Cast", _fish_cast)
	row = _row(column)
	_button(row, "Set hook", _fish_hook)
	_button(row, "Land and retain", _fish_land.bind(true))
	_button(column, "Land and release", _fish_land.bind(false))
	column.add_child(_label("Safe waiting", 27, ACCENT))
	safe_wait_label = _label("", 22, MUTED)
	column.add_child(safe_wait_label)
	row = _row(column)
	for minutes in Kernel.WAIT_MINUTES:
		wait_buttons.append(_button(row, "%d min" % minutes, _wait.bind(minutes)))
	row = _row(column)
	_button(row, "Save", _save_manual)
	_button(row, "Load", _load_manual)
	save_label = _label("Save pauses the clock. Autosave: after actions, every 30 active seconds, and on background.", 21, MUTED)
	column.add_child(save_label)
	column.add_child(HSeparator.new())
	column.add_child(_label("Scheduler test", 26, ACCENT))
	scheduler_label = _label("", 21, MUTED)
	column.add_child(scheduler_label)
	_button(column, "Interrupt next wait in 10 min", _schedule_interruption)
	column.add_child(_label("Testbed daylight: sunrise 06:00, sunset 18:00. These fixed times are test settings.", 21, MUTED))
	column.add_child(HSeparator.new())
	column.add_child(_label("New world seed", 26, ACCENT))
	seed_input = SpinBox.new()
	seed_input.min_value = 0
	seed_input.max_value = 2147483647
	seed_input.value = seed_value
	seed_input.step = 1
	seed_input.custom_minimum_size.y = 64
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(seed_input)
	_button(column, "New world", _request_new_world)

func _build_map(column: VBoxContainer) -> void:
	column.add_child(_label("Tap a zone. Links check tide, current and weather for the whole trip. Scroll for travel controls.", 22, MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	for zone in catalog.zones:
		var button := _button(grid, zone.name, select_zone.bind(String(zone.id)))
		button.custom_minimum_size.y = 110
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 23)
		var color := Color(zone.color)
		button.add_theme_stylebox_override("normal", _panel(color.darkened(0.35)))
		button.add_theme_stylebox_override("hover", _panel(color.darkened(0.15), MUTED))
		button.add_theme_stylebox_override("pressed", _panel(color.darkened(0.2), ACCENT))
		button.add_theme_stylebox_override("focus", _panel(Color.TRANSPARENT, ACCENT))
		zone_buttons[zone.id] = button
	inspector_title = _label("", 28, ACCENT)
	inspector_body = _label("", 22, MUTED)
	column.add_child(inspector_title)
	route_label = _label("", 21, MUTED)
	column.add_child(route_label)
	move_button = _button(column, "Move here", _move_selected)
	trip_button = _button(column, "Plan full trip", _plan_selected)
	column.add_child(HSeparator.new())
	column.add_child(inspector_body)

func _build_environment(column: VBoxContainer) -> void:
	column.add_child(_label("Environment", 28, ACCENT))
	environment_stamp = _label("", 21, MUTED)
	column.add_child(environment_stamp)
	weather_label = _label("", 23)
	column.add_child(weather_label)
	column.add_child(HSeparator.new())
	column.add_child(_label("Inspect zone water", 26, ACCENT))
	environment_zone = OptionButton.new()
	environment_zone.custom_minimum_size.y = 64
	environment_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for zone in catalog.zones:
		environment_zone.add_item(zone.name)
	environment_zone.item_selected.connect(func(index: int) -> void: select_zone(String(catalog.zones[index].id)))
	column.add_child(environment_zone)
	water_label = _label("", 23)
	column.add_child(water_label)
	ecology_label = _label("", 23)
	column.add_child(ecology_label)
	column.add_child(_label("Read-only lab instruments, not a player forecast. Shared coastal weather; water differs by zone. Inspecting never moves you.", 21, MUTED))
	column.add_child(_label("Synthetic 12-hour tide and 48-hour front. Rain leaves runoff; water temperature responds gradually. Not real-world safety guidance.", 21, MUTED))
	column.add_child(_label("To test quickly: go to camp, use Clock → 60 min, then return here. No background progression. Run works in every zone if a route closes.", 21, MUTED))

func _refresh_environment() -> void:
	if environment_stamp == null:
		return
	var env: Dictionary = kernel.world.environment
	var weather: Dictionary = env.weather
	last_environment_tick = int(env.updated_at_ms)
	environment_stamp.text = "Updated %s\nEvery 5 game minutes · shared regional weather" % Kernel.time_text(last_environment_tick)
	weather_label.text = "Front: %s · Pressure %.1f hPa\nAir %.2f °C · Cloud %d%%\nWind %.1f m/s from %d°\nRain %.1f mm/h · Visibility %.1f km\nTide: %s · Height +%d cm\nRunoff: %d / 1000" % [String(weather.front_state).capitalize(), float(weather.pressure_deci_hpa) / 10.0, float(weather.air_temperature_centi_c) / 100.0, weather.cloud_percent, float(weather.wind_deci_mps) / 10.0, weather.wind_from_degrees, float(weather.rain_deci_mm_hr) / 10.0, float(weather.visibility_m) / 1000.0, String(env.tide.phase).capitalize(), env.tide.height_cm, env.runoff_permille]
	for index in catalog.zones.size():
		if catalog.zones[index].id == selected_zone_id:
			environment_zone.select(index)
	var water: Dictionary = env.water_by_zone[selected_zone_id]
	if not water.water_present:
		water_label.text = "Elevated dry ground. No water body.\nDepth, current, salinity, clarity, oxygen and water temperature: not applicable."
	else:
		water_label.text = "Water depth: %d cm\nCurrent: %s · %d cm/s\nWater temperature: %.2f °C\nSalinity: %.1f ppt\nClarity: %d cm\nDissolved oxygen: %.2f mg/L" % [water.depth_cm, String(water.current_direction).capitalize(), water.current_cm_s, float(water.temperature_centi_c) / 100.0, float(water.salinity_deci_ppt) / 10.0, water.clarity_cm, float(water.oxygen_centi_mg_l) / 100.0]
	var population_lines := PackedStringArray(["Ecology ledger · updated %s" % Kernel.time_text(int(kernel.world.ecology.updated_at_ms))])
	for species in Ecology.SPECIES:
		population_lines.append("%s: %d" % [species.replace("_", " ").capitalize(), Ecology.total(kernel.world.ecology, species)])
	ecology_label.text = "\n".join(population_lines)

func _build_layers(column: VBoxContainer) -> void:
	column.add_child(_label("Player condition", 28, ACCENT))
	condition_label = _label("", 23)
	column.add_child(condition_label)
	column.add_child(_label("Starter inventory", 28, ACCENT))
	inventory_label = _label("", 23)
	column.add_child(inventory_label)
	column.add_child(HSeparator.new())
	column.add_child(_label("Simulation roadmap", 28, ACCENT))
	column.add_child(_label("Active: clock, events, six-zone travel/habitat, weather, water, environmental route checks, safe waits and saves.", 23))
	for layer in catalog.layers:
		column.add_child(_label(layer.name, 25, ACCENT))
		var detail: String = layer.description
		if layer.name == "Clock and calendar":
			detail += " Active in Phase 2A; fixed testbed daylight."
		elif layer.name == "Habitat":
			detail += " Active as zone tags and access records; no ecological simulation yet."
		elif layer.name in ["Weather", "Water"]:
			detail += " Active in Phase 2C as a simplified coastal systems test."
		elif layer.name == "Persistence and audit":
			detail += " Active for the current kernel; later layers will extend its schema."
		else:
			detail += " Planned."
		column.add_child(_label(detail, 21, MUTED))
	column.add_child(HSeparator.new())
	column.add_child(_label("Initial species", 28, ACCENT))
	for species in catalog.species:
		column.add_child(_label(species.name, 23))
	column.add_child(_label("Shown per habitat as potential use only. Populations and behavior arrive with ecology.", 22, MUTED))

func _status(message: String) -> void:
	if status_label != null:
		status_label.text = message

func _refresh_clock() -> void:
	if clock_label == null:
		return
	clock_label.text = Kernel.time_text(kernel.world.game_time_ms)
	calendar_label.text = "%s · %s · %s" % [kernel.date_text(), kernel.light_state(), "RUNNING" if session.running else "PAUSED"]
	location_label.text = "At " + _zone_name(kernel.world.player_zone) + "  ·  Seed " + str(kernel.world.seed)
	run_button.text = "Pause clock" if session.running else "Run clock"
	last_display_second = int(kernel.world.game_time_ms / 1000)
	var next: Dictionary = kernel.world.scheduled[0]
	scheduler_label.text = "%d events pending. Next: %s at %s." % [kernel.world.scheduled.size(), next.kind, Kernel.time_text(int(next.due_ms))]

func _refresh_log() -> void:
	var lines := PackedStringArray()
	for entry in kernel.world.history:
		lines.append("#%d  %s\n%s" % [entry.id, Kernel.time_text(int(entry.time_ms)), entry.detail])
	event_log.text = "\n\n".join(lines)

func _refresh() -> void:
	if clock_label == null:
		return
	_refresh_clock()
	_refresh_log()
	select_zone(selected_zone_id)
	var at_camp := kernel.world.player_zone == "elevated_camp"
	for button in wait_buttons:
		button.disabled = not at_camp or save_blocked
	safe_wait_label.text = "At camp. Waits process every scheduled event and can be interrupted." if at_camp else "Travel to elevated camp to wait safely."
	run_button.disabled = save_blocked or not session.blocked.is_empty()
	if condition_label != null:
		var c: Dictionary = kernel.world.condition
		condition_label.text = "Hydration %d/1000 · Energy %d/1000\nExposure %d/1000 · Sleep debt %d/1000\nHealth %d/1000 · Updated %s" % [c.hydration, c.energy, c.exposure, c.sleep_debt, c.health, Kernel.time_text(int(c.updated_at_ms))]
		var items: Dictionary = kernel.world.inventory.items
		inventory_label.text = "Water %d mL · Rations %d kcal\nRaw fish %d g · Firewood %d · Bait %d" % [items.water_ml, items.food_kcal, items.fish_food_g, items.firewood_units, items.bait_units]

func _zone_name(zone_id: String) -> String:
	for zone in catalog.zones:
		if zone.id == zone_id:
			return zone.name
	return zone_id

func select_zone(zone_id: String) -> void:
	if not zone_buttons.has(zone_id):
		return
	selected_zone_id = zone_id
	for zone in catalog.zones:
		zone_buttons[zone.id].set_pressed_no_signal(zone.id == zone_id)
		zone_buttons[zone.id].text = zone.name + ("\nYOU ARE HERE" if zone.id == kernel.world.player_zone else "\n" + zone.kind)
		if zone.id == zone_id:
			inspector_title.text = zone.name
			var record: Dictionary = Map.ZONES[zone_id]
			var route_lines := PackedStringArray()
			for route in Map.routes_from(zone_id):
				var preview := kernel.route_preview(zone_id, String(route.to))
				route_lines.append("→ %s: %s\n%s" % [_zone_name(route.to), Map.route_text(route), "OPEN" if preview.ok else "BLOCKED: " + preview.reason])
			var species_names := PackedStringArray()
			for species_id in record.species_ids:
				for species in catalog.species:
					if species.id == species_id:
						species_names.append(species.name)
			inspector_body.text = "%s\n\nTerrain: %s\nExposure: %s\nHabitat: %s\nPotential species: %s\n\nRoutes from here:\n%s" % [zone.purpose, record.terrain, record.exposure, ", ".join(record.habitat_tags), ", ".join(species_names) if not species_names.is_empty() else "None", "\n".join(route_lines)]
	var travel := kernel.travel_result(zone_id)
	if zone_id == kernel.world.player_zone:
		route_label.text = "Current location. Choose a linked zone to travel."
		move_button.text = "You are here"
		move_button.disabled = true
		trip_button.text = "Choose a destination"
		trip_button.disabled = true
	elif travel.ok:
		var route: Dictionary = travel.route
		route_label.text = "Direct route: " + Map.route_text(route)
		move_button.text = "Travel by %s · %d min" % [route.mode, int(route.minutes)]
		move_button.disabled = save_blocked
		var plan := kernel.route_plan(zone_id)
		trip_button.text = "Travel full route · %d min" % int(plan.minutes) if plan.ok else "Full route blocked"
		trip_button.disabled = save_blocked or not plan.ok
	else:
		route_label.text = "Blocked: " + travel.reason
		move_button.text = "Route unavailable"
		move_button.disabled = true
		var plan := kernel.route_plan(zone_id)
		if plan.ok:
			var plan_names := PackedStringArray()
			for stop in plan.path:
				plan_names.append(_zone_name(String(stop)))
			route_label.text = "Full route: " + " → ".join(plan_names) + " · %d min" % int(plan.minutes)
			trip_button.text = "Travel full route · %d min" % int(plan.minutes)
			trip_button.disabled = save_blocked
		else:
			trip_button.text = "Full route blocked"
			trip_button.disabled = true
			route_label.text += "\nFull route blocked: " + String(plan.reason)
	_refresh_environment()

func _toggle_running() -> void:
	session.set_running(not session.running and not save_blocked)
	_status("Clock running at 6:1." if session.running else "Clock paused.")
	if not session.running:
		_autosave()
	_refresh()

func _can_act() -> bool:
	session.set_running(false)
	if save_blocked:
		_status("Saved world needs recovery. Use New world to reset autosave.")
		return false
	return true

func _after_action(result: Dictionary) -> void:
	_status(result.get("message", "Action completed."))
	if result.ok:
		_autosave()
	_refresh()

func _observe() -> void:
	if _can_act():
		_after_action(kernel.observe())

func _fish_rig() -> void:
	if _can_act():
		_after_action(kernel.rig_fishing())

func _fish_cast() -> void:
	if _can_act():
		_after_action(kernel.cast_fishing())

func _fish_hook() -> void:
	if _can_act():
		_after_action(kernel.hook_fishing())

func _fish_land(retain: bool) -> void:
	if _can_act():
		_after_action(kernel.land_fishing(retain))

func _move_to(destination: String) -> void:
	if _can_act():
		var result := kernel.move_plan(destination) if destination == "elevated_camp" else kernel.move(destination)
		if result.ok:
			selected_zone_id = destination
		_after_action(result)

func _move_selected() -> void:
	_move_to(selected_zone_id)

func _plan_selected() -> void:
	if _can_act():
		var result := kernel.move_plan(selected_zone_id)
		if result.ok:
			selected_zone_id = kernel.world.player_zone
		_after_action(result)

func _wait(minutes: int) -> void:
	if _can_act():
		_after_action(kernel.wait_minutes(minutes))

func _schedule_interruption() -> void:
	if _can_act():
		var result := kernel.schedule_marker(10 * Kernel.MINUTE_MS, "Test wait interruption", true)
		if result.ok:
			result.message = "Interruption in 10 game minutes. At camp, wait 15 min to test."
		_after_action(result)

func _save_manual() -> void:
	if not _can_act():
		return
	var result := saves.save_slot("manual", kernel.world.to_record())
	if result.ok:
		save_label.text = "Manual save: %s\nState %s · %d ms" % [Kernel.time_text(kernel.world.game_time_ms), result.fingerprint.left(12), kernel.world.game_time_ms]
		_status("Manual save complete. Clock paused.")
		_autosave()
	else:
		_status(result.message)
	_refresh()

func _load_manual() -> void:
	session.set_running(false)
	var result := saves.load_slot("manual")
	if result.ok:
		kernel.restore(result.record)
		save_blocked = false
		seed_value = kernel.world.seed
		seed_input.value = seed_value
		selected_zone_id = kernel.world.player_zone
		save_label.text = "Loaded state %s · %d ms" % [SaveStore.fingerprint(result.record).left(12), kernel.world.game_time_ms]
		_status(result.get("message", "Manual save loaded exactly. Clock paused."))
		_autosave()
	else:
		_status("Load failed: " + result.message)
	_refresh()

func _autosave(allow_replace: bool = false) -> void:
	if save_blocked:
		return
	var result := saves.save_slot("autosave", kernel.world.to_record(), allow_replace)
	if not result.ok:
		_status("Autosave failed: " + result.message)
	autosave_game_ms = 0

func _request_new_world() -> void:
	session.set_running(false)
	_refresh()
	new_world_dialog.popup_centered(Vector2i(440, 240))

func _new_world() -> void:
	seed_input.apply()
	seed_value = int(seed_input.value)
	kernel = Kernel.new(seed_value)
	session.kernel = kernel
	session.set_running(false)
	save_blocked = false
	selected_zone_id = kernel.world.player_zone
	_status("New world started at 06:00. Clock paused.")
	_autosave(true)
	_refresh()
