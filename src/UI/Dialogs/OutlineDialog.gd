extends ConfirmationDialog

func _ready() -> void:
	$OptionsContainer/OutlineColor.get_picker().presets_visible = false


func _on_OutlineDialog_confirmed() -> void:
	var outline_color : Color = $OptionsContainer/OutlineColor.color
	var thickness : int = $OptionsContainer/ThickValue.value
	var diagonal : bool = $OptionsContainer/DiagonalCheckBox.pressed
	var inside_image : bool = $OptionsContainer/InsideImageCheckBox.pressed

	var image : Image = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	DrawingAlgos.generate_outline(image, outline_color, thickness, diagonal, inside_image)
