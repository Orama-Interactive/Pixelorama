extends ConfirmationDialog


func _on_ScaleImage_confirmed() -> void:
	var width : int = $VBoxContainer/OptionsContainer/WidthValue.value
	var height : int = $VBoxContainer/OptionsContainer/HeightValue.value
	var interpolation : int = $VBoxContainer/OptionsContainer/InterpolationType.selected
	Global.undos += 1
	Global.undo_redo.create_action("Scale")

	for c in Global.canvases:
		Global.undo_redo.add_do_property(c, "size", Vector2(width, height).floor())
		for i in range(c.layers.size() - 1, -1, -1):
			var sprite := Image.new()
			sprite.copy_from(c.layers[i][0])
			sprite.resize(width, height, interpolation)
			Global.undo_redo.add_do_property(c.layers[i][0], "data", sprite.data)
			Global.undo_redo.add_undo_property(c.layers[i][0], "data", c.layers[i][0].data)
		Global.undo_redo.add_undo_property(c, "size", c.size)

	Global.undo_redo.add_undo_method(Global, "undo", Global.canvases)
	Global.undo_redo.add_do_method(Global, "redo", Global.canvases)
	Global.undo_redo.commit_action()
