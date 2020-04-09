extends ConfirmationDialog

onready var templates_options = $VBoxContainer/OptionsContainer/TemplatesOptions
onready var ratio_box = $VBoxContainer/OptionsContainer/RatioCheckBox
onready var width_value = $VBoxContainer/OptionsContainer/WidthValue
onready var height_value = $VBoxContainer/OptionsContainer/HeightValue
onready var fill_color_node = $VBoxContainer/OptionsContainer/FillColor

#Template Id identifier
enum Templates {
	TDefault = 0,
	T16 = 1,
	T32 = 2,
	T64 = 3,
	T128 = 4,
}
#Template actual value, without Default because we get it from Global
enum TValues {
	T16 = 16,
	T32 = 32,
	T64 = 64,
	T128 = 128,
}

func _ready() -> void:
	ratio_box.connect("pressed", self, "_on_RatioCheckBox_toggled", [ratio_box.pressed])
	templates_options.connect("item_selected", self, "_on_TemplatesOptions_item_selected")

func _on_CreateNewImage_confirmed() -> void:
	var width : int = width_value.value
	var height : int = height_value.value
	var fill_color : Color = fill_color_node.color
	Global.clear_canvases()
	Global.layers.clear()
	# Store [Layer name (0), Layer visibility boolean (1), Layer lock boolean (2), Frame container (3),
	# will new frames be linked boolean (4), Array of linked frames (5)]
	Global.layers.append([tr("Layer") + " 0", true, false, HBoxContainer.new(), false, []])
	Global.current_layer = 0
	Global.canvas = load("res://Prefabs/Canvas.tscn").instance()
	Global.canvas.size = Vector2(width, height).floor()

	Global.canvases.append(Global.canvas)
	Global.canvas_parent.add_child(Global.canvas)
	Global.canvases = Global.canvases # To trigger Global.canvases_changed()
	Global.current_frame = 0
	Global.layers = Global.layers # To trigger Global.layers_changed()
	Global.saved = true
	if fill_color.a > 0:
		Global.canvas.layers[0][0].fill(fill_color)
		Global.canvas.layers[0][0].lock()
		Global.canvas.update_texture(0)

func _on_CreateNewImage_about_to_show() -> void:
	width_value.value = Global.default_image_width
	height_value.value = Global.default_image_height
	fill_color_node.color = Global.default_fill_color
	templates_options.selected = Templates.TDefault
	ratio_box.pressed = false
	for spin_box in [width_value, height_value]:
		if spin_box.is_connected("value_changed", self, "_on_SizeValue_value_changed"):
			spin_box.disconnect("value_changed", self, "_on_SizeValue_value_changed")

var aspect_ratio: float

# warning-ignore:unused_argument
func _on_RatioCheckBox_toggled(button_pressed: bool) -> void:
	aspect_ratio = width_value.value / height_value.value
	for spin_box in [width_value, height_value]:
		if spin_box.is_connected("value_changed", self, "_on_SizeValue_value_changed"):
			spin_box.disconnect("value_changed", self, "_on_SizeValue_value_changed")
		else:
			spin_box.connect("value_changed", self, "_on_SizeValue_value_changed")

func _on_SizeValue_value_changed(value: float) -> void:
	if width_value.value == value:
		height_value.value = width_value.value / aspect_ratio
	if height_value.value == value:
		width_value.value = height_value.value * aspect_ratio

func _on_TemplatesOptions_item_selected(id: int) -> void:
	match id:
		Templates.TDefault:
			width_value.value = Global.default_image_width
			height_value.value = Global.default_image_height
		Templates.T16:
			width_value.value = TValues.T16
			height_value.value = TValues.T16
		Templates.T32:
			width_value.value = TValues.T32
			height_value.value = TValues.T32
		Templates.T64:
			width_value.value = TValues.T64
			height_value.value = TValues.T64
		Templates.T128:
			width_value.value = TValues.T128
			height_value.value = TValues.T128
