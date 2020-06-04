extends ConfirmationDialog


func _on_ScaleImage_confirmed() -> void:
	var width : int = $VBoxContainer/OptionsContainer/WidthValue.value
	var height : int = $VBoxContainer/OptionsContainer/HeightValue.value
	var interpolation : int = $VBoxContainer/OptionsContainer/InterpolationType.selected
	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Scale")
	Global.current_project.undo_redo.add_do_property(Global.canvas, "size", Vector2(width, height).floor())

	for f in Global.current_project.frames:
		for i in range(f.cels.size() - 1, -1, -1):
			var sprite := Image.new()
			sprite.copy_from(f.cels[i].image)
			sprite.resize(width, height, interpolation)
			Global.current_project.undo_redo.add_do_property(f.cels[i].image, "data", sprite.data)
			Global.current_project.undo_redo.add_undo_property(f.cels[i].image, "data", f.cels[i].image.data)

	Global.current_project.undo_redo.add_undo_property(Global.canvas, "size", Global.canvas.size)
	Global.current_project.undo_redo.add_undo_method(Global, "undo")
	Global.current_project.undo_redo.add_do_method(Global, "redo")
	Global.current_project.undo_redo.commit_action()
