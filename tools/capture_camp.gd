extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	if OS.get_environment("CAMP_SCENE") in ["game", "mini", "built"]:
		main.start_game(false)
		main.close_dialog()
		if OS.get_environment("CAMP_SCENE") in ["mini", "built"]:
			main.s.phase = "build"
			main.s.build_stage = 1
			main.s.player = Vector2(365,565)
			if OS.get_environment("CAMP_SCENE") == "mini": main.mini = true
	for i in range(10): await process_frame
	await create_timer(0.3).timeout
	var path := OS.get_environment("CAMP_CAPTURE")
	var error := root.get_texture().get_image().save_png(path)
	print("[camp-capture] ", path, " ", error_string(error))
	main.s.reset_save()
	quit(0 if error == OK else 1)
