extends ConfirmationDialog


func _on_ResizeCanvas_confirmed() -> void:
	var width : int = $VBoxContainer/OptionsContainer/WidthValue.value
	var height : int = $VBoxContainer/OptionsContainer/HeightValue.value
	DrawingAlgos.resize_canvas(width, height)
