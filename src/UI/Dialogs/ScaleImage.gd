extends ConfirmationDialog


func _on_ScaleImage_confirmed() -> void:
	var width : int = $VBoxContainer/OptionsContainer/WidthValue.value
	var height : int = $VBoxContainer/OptionsContainer/HeightValue.value
	var interpolation : int = $VBoxContainer/OptionsContainer/InterpolationType.selected
	Global.undos += 1
	Global.undo_redo.create_action("Scale")
	Global.undo_redo.add_do_property(Global.canvas, "size", Vector2(width, height).floor())

	for i in range(Global.canvas.layers.size() - 1, -1, -1):
		var sprite : Image = Global.canvas.layers[i][1].get_data()
		sprite.resize(width, height, interpolation)
		Global.undo_redo.add_do_property(Global.canvas.layers[i][0], "data", sprite.data)
		Global.undo_redo.add_undo_property(Global.canvas.layers[i][0], "data", Global.canvas.layers[i][0].data)

	Global.undo_redo.add_undo_property(Global.canvas, "size", Global.canvas.size)
	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
	Global.undo_redo.commit_action()
