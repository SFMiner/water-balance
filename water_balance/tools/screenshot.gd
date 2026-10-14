# Screenshot gate (windowed, not headless): keeps a Medium-water run, then shows Lots of water paused at WB_T
# model seconds (optional WB_PACE 0-1, WB_LENGTH 0-2 for 4/6/8 hours). WB_T=40 WB_OUT=<absolute png> Godot --path . --resolution 1280x720 --script res://tools/screenshot.gd
extends SceneTree
func _init() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	await process_frame
	if not OS.get_environment("WB_PACE").is_empty():
		main.set_pace(int(OS.get_environment("WB_PACE")))
	if not OS.get_environment("WB_LENGTH").is_empty():
		main.set_length(int(OS.get_environment("WB_LENGTH")))
	main.set_amount(1)
	main.toggle_run()
	main.controller.advance(main.controller.duration())
	main.keep_run()
	main.controller.restart()
	main.set_amount(2)
	main.toggle_run()
	main.controller.advance(float(OS.get_environment("WB_T")))
	main.controller.pause()
	for i: int in range(10):
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("WB_OUT"))
	quit()
