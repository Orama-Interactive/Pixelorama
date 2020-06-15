extends "res://src/Tools/Base.gd"


var _zoom_mode := 0


func _on_ModeOptions_item_selected(id):
	_zoom_mode = id
	update_config()
	save_config()


func _on_FitToFrame_pressed():
	Global.camera.fit_to_frame(Global.current_project.size)


func _on_100_pressed():
	Global.camera.zoom = Vector2.ONE
	Global.camera.offset = Global.current_project.size / 2
	Global.zoom_level_label.text = str(round(100 / Global.camera.zoom.x)) + " %"
	Global.horizontal_ruler.update()
	Global.vertical_ruler.update()


func get_config() -> Dictionary:
	return {
		"zoom_mode" : _zoom_mode,
	}


func set_config(config : Dictionary) -> void:
	_zoom_mode = config.get("zoom_mode", _zoom_mode)


func update_config() -> void:
	$ModeOptions.selected = _zoom_mode


func draw_start(_position : Vector2) -> void:
	Global.camera.zoom_camera(_zoom_mode * 2 - 1)


func draw_move(_position : Vector2) -> void:
	pass


func draw_end(_position : Vector2) -> void:
	pass
