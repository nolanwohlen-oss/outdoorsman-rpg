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
	app.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
