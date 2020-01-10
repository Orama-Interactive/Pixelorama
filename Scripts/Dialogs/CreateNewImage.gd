extends ConfirmationDialog

onready var width_value = $VBoxContainer/OptionsContainer/WidthValue
onready var height_value = $VBoxContainer/OptionsContainer/HeightValue
onready var fill_color_node = $VBoxContainer/OptionsContainer/FillColor

func _on_CreateNewImage_confirmed() -> void:
	var width : int = width_value.value
	var height : int = height_value.value
	var fill_color : Color = fill_color_node.color
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

func _on_CreateNewImage_about_to_show() -> void:
	width_value.value = Global.default_image_width
	height_value.value = Global.default_image_height
	fill_color_node.color = Global.default_fill_color
