extends ConfirmationDialog

onready var templates_options = $VBoxContainer/OptionsContainer/TemplatesOptions
onready var ratio_box = $VBoxContainer/OptionsContainer/RatioCheckBox
onready var width_value = $VBoxContainer/OptionsContainer/WidthValue
onready var height_value = $VBoxContainer/OptionsContainer/HeightValue
onready var fill_color_node = $VBoxContainer/OptionsContainer/FillColor

onready var size_value = Vector2()

# Template Id identifier
enum Templates {
	TDefault = 0,
	T16 = 1,
	T32 = 2,
	T64 = 3,
	T128 = 4,
	GB = 5,
	GBA = 6,
	NES_NTSC = 7,
	NES_PAL = 8,
	SNES_NTSC = 9,
	SNES_PAL = 10
}
# Template actual value, without Default because we get it from Global
var TResolutions = {
	Templates.T16: Vector2(16,16),
	Templates.T32: Vector2(32,32),
	Templates.T64: Vector2(64,64),
	Templates.T128: Vector2(128,128),

	Templates.GB: Vector2(160,144),
	Templates.GBA: Vector2(240,160),
	Templates.NES_NTSC: Vector2(256,224),
	Templates.NES_PAL: Vector2(256,240),
	Templates.SNES_NTSC: Vector2(512,448),
	Templates.SNES_PAL: Vector2(512,480),
}

var TStrings ={
	Templates.T16: "",
	Templates.T32: "",
	Templates.T64: "",
	Templates.T128: "",

	Templates.GB: "GB",
	Templates.GBA: "GBA",
	Templates.NES_NTSC: "NES (NTSC)",
	Templates.NES_PAL: "NES (PAL)",
	Templates.SNES_NTSC: "SNES (NTSC)",
	Templates.SNES_PAL: "SNES (PAL)"
	}


func _ready() -> void:
	fill_color_node.get_picker().presets_visible = false
	ratio_box.connect("pressed", self, "_on_RatioCheckBox_toggled", [ratio_box.pressed])
	templates_options.connect("item_selected", self, "_on_TemplatesOptions_item_selected")

	_CreateOptionList()


func _CreateOptionList() -> void:
	for i in Templates.values():
		if i > 0:
			if TStrings[i] != "":
				templates_options.add_item("{width}x{height} - {name}".format({"width":TResolutions[i].x, "height":TResolutions[i].y, "name":TStrings[i]}), i)
			else:
				templates_options.add_item("{width}x{height}".format({"width":TResolutions[i].x, "height":TResolutions[i].y}), i)


func _on_CreateNewImage_confirmed() -> void:
	var width : int = width_value.value
	var height : int = height_value.value
	var fill_color : Color = fill_color_node.color
	Global.clear_frames()
	Global.layers.clear()
	Global.layers.append(Layer.new())
	Global.canvas.size = Vector2(width, height).floor()
	Global.canvas.fill_color = fill_color
	var frame : Frame = Global.canvas.new_empty_frame()
	Global.canvas.camera_zoom()
	Global.frames.append(frame)

	Global.current_layer = 0
	Global.frames = Global.frames # To trigger Global.frames_changed()
	Global.current_frame = 0
	Global.layers = Global.layers # To trigger Global.layers_changed()
	Global.project_has_changed = false
	if fill_color.a > 0:
		Global.frames[0].cels[0].image.fill(fill_color)
		Global.frames[0].cels[0].image.lock()
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

func _on_RatioCheckBox_toggled(_button_pressed: bool) -> void:
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
	if id != Templates.TDefault:
		size_value = TResolutions[id]
	else:
		width_value.value = Global.default_image_width
		height_value.value = Global.default_image_height

	width_value.value = size_value.x
	height_value.value = size_value.y
