extends SceneTree

func _init() -> void:
	_capture.call_deferred()

func _capture() -> void:
	root.size = Vector2i(540, 960)
	var app = load("res://scenes/main.tscn").instantiate()
	app.save_directory = "res://build/capture-%d" % OS.get_process_id()
	root.add_child(app)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://build")
	var error := picture.save_png("res://build/shell-preview.png")
	app.tabs.current_tab = 3
	load("res://simulation/inventory.gd").add_fish(app.kernel.world.inventory, "mullet", 800, app.kernel.world.game_time_ms, app.kernel.world.player_zone)
	app._refresh()
	app.item_picker.select(app.item_picker.item_count - 1)
	app._refresh_item_details()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://build/inventory-preview.png") != OK:
		error = FAILED
	app.tabs.current_tab = 0
	app._move_to("elevated_camp")
	app._wait(15)
	app._save_manual()
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://build/camp-preview.png") != OK:
		error = FAILED
	app.tabs.current_tab = 1
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://build/map-preview.png") != OK:
		error = FAILED
	# Rainy environment, zone water, and a real high-tide route closure.
	app.kernel.advance_game_ms(11 * 3600000)
	app.select_zone("marsh_edge")
	app._refresh()
	app.tabs.current_tab = 2
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://build/environment-preview.png") != OK:
		error = FAILED
	app.tabs.get_child(2).scroll_vertical = 340
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://build/water-preview.png") != OK:
		error = FAILED
	app.kernel = load("res://simulation/kernel.gd").new(42)
	app.session.kernel = app.kernel
	app.kernel.advance_game_ms(6 * 3600000)
	app.select_zone("shallow_flat")
	app._refresh()
	app.tabs.current_tab = 1
	await process_frame
	await process_frame
	# Scroll after the selected tab has completed layout, keeping its action visible.
	app.tabs.get_child(1).scroll_vertical = int(app.inspector_title.position.y)
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://build/blocked-route-preview.png") != OK:
		error = FAILED
	# Capture the Phase 2M hooked-fish controls and diagnostic state.
	app.kernel = load("res://simulation/kernel.gd").new(42)
	app.session.kernel = app.kernel
	app.kernel.rig_fishing()
	app.kernel.cast_fishing()
	app.kernel.advance_game_ms(load("res://simulation/fishing.gd").BITE_DELAY_MS)
	app.kernel.hook_fishing()
	app.tabs.current_tab = 0
	app._refresh()
	await process_frame
	await process_frame
	app.tabs.get_child(0).scroll_vertical = 140
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://build/fight-preview.png") != OK:
		error = FAILED
	app.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
