extends SceneTree

func _init() -> void:
	_capture.call_deferred()

func _capture() -> void:
	root.size = Vector2i(540, 960)
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://build")
	var error := picture.save_png("res://build/shell-preview.png")
	app.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
