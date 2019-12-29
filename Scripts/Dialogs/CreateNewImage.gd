extends ConfirmationDialog

func _on_CreateNewImage_confirmed() -> void:
	var width : int = $VBoxContainer/OptionsContainer/WidthValue.value
	var height : int = $VBoxContainer/OptionsContainer/HeightValue.value
	var fill_color : Color = $VBoxContainer/OptionsContainer/FillColor.color
	Global.control.clear_canvases()
	Global.canvas = load("res://Prefabs/Canvas.tscn").instance()
	Global.canvas.size = Vector2(width, height).floor()

	Global.canvases.append(Global.canvas)
	Global.canvas_parent.add_child(Global.canvas)
	Global.current_frame = 0
	if fill_color.a > 0:
		Global.canvas.layers[0][0].fill(fill_color)
		Global.canvas.layers[0][0].lock()
		Global.canvas.update_texture(0)
	Global.undo_redo.clear_history(false)
