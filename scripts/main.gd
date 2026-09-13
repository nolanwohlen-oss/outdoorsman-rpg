extends Control
## Phase 1 UI only. No world time, population, progression, or save mutations.

const Catalog = preload("res://scripts/catalog.gd")
const TEXT := Color("e8eee2")
const MUTED := Color("a8bcb3")
const ACCENT := Color("d8bd83")

var catalog: Dictionary
var selected_zone_id := ""
var zone_buttons: Dictionary = {}
var inspector_title: Label
var inspector_body: Label
var event_log: RichTextLabel
var seed_input: SpinBox
var seed_value := 13092026
var events := PackedStringArray()
var tabs: TabContainer

func _ready() -> void:
	theme = _theme()
	catalog = Catalog.read()
	var problems := Catalog.validate(catalog)
	if not problems.is_empty():
		var error_label := _label("Catalog error\n" + "\n".join(problems), 28, ACCENT)
		add_child(error_label)
		push_error(error_label.text)
		return
	seed_value = int(catalog.default_seed)
	_build_interface()
	select_zone("sandy_shore")
	_log("Project shell ready. Simulation layers are not active yet.")

func _theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 25
	result.set_color("font_color", "Label", TEXT)
	result.set_color("default_color", "RichTextLabel", MUTED)
	for state in ["normal", "hover", "pressed", "focus"]:
		result.set_stylebox(state, "Button", _panel(Color("1b3335"), Color("46615a")))
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_pressed_color", "Button", ACCENT)
	result.set_color("font_hover_color", "Button", TEXT)
	result.set_constant("h_separation", "TabBar", 30)
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
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func _label(value: String, font_size := 25, color := TEXT) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _column(parent: Node, separation := 16) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box

func _scroll_tab(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(scroll)
	return _column(scroll, 20)

func _build_interface() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := _column(margin, 16)
	layout.add_child(_label("OUTDOORSMAN", 39))
	layout.add_child(_label("SYSTEMS LAB  /  PHASE 1", 22, ACCENT))
	layout.add_child(_label("Generic coastal testbed", 28))
	layout.add_child(_label("Inspect the map and planned layers. Simulation is not running in this build.", 23, MUTED))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	_build_map(_scroll_tab("Map"))
	_build_layers(_scroll_tab("Layers"))
	var log_column := _scroll_tab("Log")
	log_column.add_child(_label("Session event log", 28, ACCENT))
	log_column.add_child(_label("Interface events only. This log resets when the application closes.", 23, MUTED))
	event_log = RichTextLabel.new()
	event_log.fit_content = true
	event_log.custom_minimum_size.y = 120
	event_log.add_theme_font_size_override("normal_font_size", 24)
	log_column.add_child(event_log)
	var build := "v0.1.0 · local build"
	if FileAccess.file_exists("res://config/build_info.json"):
		var info = JSON.parse_string(FileAccess.get_file_as_string("res://config/build_info.json"))
		if info is Dictionary:
			build = "v0.1.0 · build %s · %s" % [info.get("number", "local"), info.get("commit", "unknown")]
	layout.add_child(_label(build, 20, MUTED))

func _build_map(column: VBoxContainer) -> void:
	column.add_child(_label("Tap a zone to inspect it", 23, MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	for zone in catalog.zones:
		var button := Button.new()
		button.text = zone.name + "\n" + zone.kind
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 114)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 25)
		var color := Color(zone.color)
		button.add_theme_stylebox_override("normal", _panel(color.darkened(0.35)))
		button.add_theme_stylebox_override("hover", _panel(color.darkened(0.15), MUTED))
		button.add_theme_stylebox_override("pressed", _panel(color.darkened(0.2), ACCENT))
		button.add_theme_stylebox_override("focus", _panel(Color.TRANSPARENT, ACCENT))
		button.pressed.connect(select_zone.bind(String(zone.id)))
		grid.add_child(button)
		zone_buttons[zone.id] = button
	inspector_title = _label("", 29, ACCENT)
	inspector_body = _label("", 24, MUTED)
	column.add_child(inspector_title)
	column.add_child(inspector_body)
	column.add_child(HSeparator.new())
	column.add_child(_label("Scenario seed", 26))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	seed_input = SpinBox.new()
	seed_input.min_value = 0
	seed_input.max_value = 2147483647
	seed_input.value = seed_value
	seed_input.step = 1
	seed_input.custom_minimum_size.y = 62
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(seed_input)
	var apply := Button.new()
	apply.text = "Set seed"
	apply.custom_minimum_size = Vector2(160, 62)
	apply.pressed.connect(_set_seed)
	row.add_child(apply)
	column.add_child(_label("Reserved for the deterministic simulation. Changing it currently records a session setting only.", 21, MUTED))

func _build_layers(column: VBoxContainer) -> void:
	column.add_child(_label("Simulation roadmap", 29, ACCENT))
	column.add_child(_label("All nine layers below are planned. This build verifies the application and export pipeline.", 24, MUTED))
	for layer in catalog.layers:
		column.add_child(_label(layer.name + "  ·  Phase " + str(int(layer.phase)), 25))
		column.add_child(_label(layer.description, 22, MUTED))
	column.add_child(HSeparator.new())
	column.add_child(_label("Initial species", 29, ACCENT))
	for species in catalog.species:
		column.add_child(_label(species.name, 24))
	column.add_child(_label("Names only at this milestone. Populations and behavior arrive with the ecology layer.", 22, MUTED))

func select_zone(zone_id: String) -> void:
	for zone in catalog.zones:
		if zone.id != zone_id:
			continue
		selected_zone_id = zone_id
		for button_id in zone_buttons:
			zone_buttons[button_id].set_pressed_no_signal(button_id == zone_id)
		inspector_title.text = zone.name
		var neighbor_names := PackedStringArray()
		for neighbor_id in zone.neighbors:
			for neighbor in catalog.zones:
				if neighbor.id == neighbor_id:
					neighbor_names.append(neighbor.name)
		inspector_body.text = "%s\n\nConnections: %s\nPlaceholder geometry; physical access rules are pending." % [zone.purpose, ", ".join(neighbor_names)]
		_log("Inspected " + zone.name + ".")
		return

func _set_seed() -> void:
	seed_input.apply()
	seed_value = int(seed_input.value)
	_log("Scenario seed set to %d. No world has been generated." % seed_value)

func _log(message: String) -> void:
	events.append("%02d  %s" % [events.size() + 1, message])
	if events.size() > 100:
		events.remove_at(0)
	if event_log != null:
		event_log.text = "\n\n".join(events)
