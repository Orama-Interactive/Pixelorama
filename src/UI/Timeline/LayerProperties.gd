extends AcceptDialog

var layer_indices: PackedInt32Array

@onready var name_line_edit := $GridContainer/NameLineEdit as LineEdit
@onready var opacity_slider := $GridContainer/OpacitySlider as ValueSlider
@onready var blend_modes_button := $GridContainer/BlendModeOptionButton as OptionButton
@onready var user_data_text_edit := $GridContainer/UserDataTextEdit as TextEdit


func _ready() -> void:
	# Fill the blend modes OptionButton with items
	blend_modes_button.add_item("Normal", BaseLayer.BlendModes.NORMAL)
	blend_modes_button.add_item("Darken", BaseLayer.BlendModes.DARKEN)
	blend_modes_button.add_item("Multiply", BaseLayer.BlendModes.MULTIPLY)
	blend_modes_button.add_item("Color burn", BaseLayer.BlendModes.COLOR_BURN)
	blend_modes_button.add_item("Linear burn", BaseLayer.BlendModes.LINEAR_BURN)
	blend_modes_button.add_item("Lighten", BaseLayer.BlendModes.LIGHTEN)
	blend_modes_button.add_item("Screen", BaseLayer.BlendModes.SCREEN)
	blend_modes_button.add_item("Color dodge", BaseLayer.BlendModes.COLOR_DODGE)
	blend_modes_button.add_item("Add", BaseLayer.BlendModes.ADD)
	blend_modes_button.add_item("Overlay", BaseLayer.BlendModes.OVERLAY)
	blend_modes_button.add_item("Soft light", BaseLayer.BlendModes.SOFT_LIGHT)
	blend_modes_button.add_item("Hard light", BaseLayer.BlendModes.HARD_LIGHT)
	blend_modes_button.add_item("Difference", BaseLayer.BlendModes.DIFFERENCE)
	blend_modes_button.add_item("Exclusion", BaseLayer.BlendModes.EXCLUSION)
	blend_modes_button.add_item("Subtract", BaseLayer.BlendModes.SUBTRACT)
	blend_modes_button.add_item("Divide", BaseLayer.BlendModes.DIVIDE)
	blend_modes_button.add_item("Hue", BaseLayer.BlendModes.HUE)
	blend_modes_button.add_item("Saturation", BaseLayer.BlendModes.SATURATION)
	blend_modes_button.add_item("Color", BaseLayer.BlendModes.COLOR)
	blend_modes_button.add_item("Luminosity", BaseLayer.BlendModes.LUMINOSITY)


func _on_visibility_changed() -> void:
	if layer_indices.size() == 0:
		return
	Global.dialog_open(visible)
	var first_layer := Global.current_project.layers[layer_indices[0]]
	if visible:
		name_line_edit.text = first_layer.name
		opacity_slider.value = first_layer.opacity * 100.0
		blend_modes_button.selected = first_layer.blend_mode
		user_data_text_edit.text = first_layer.user_data
	else:
		layer_indices = []


func _on_name_line_edit_text_changed(new_text: String) -> void:
	if layer_indices.size() == 0:
		return
	for layer_index in layer_indices:
		var layer := Global.current_project.layers[layer_index]
		layer.name = new_text


func _on_opacity_slider_value_changed(value: float) -> void:
	if layer_indices.size() == 0:
		return
	for layer_index in layer_indices:
		var layer := Global.current_project.layers[layer_index]
		layer.opacity = value / 100.0
	Global.canvas.queue_redraw()


func _on_blend_mode_option_button_item_selected(index: BaseLayer.BlendModes) -> void:
	if layer_indices.size() == 0:
		return
	for layer_index in layer_indices:
		var layer := Global.current_project.layers[layer_index]
		layer.blend_mode = index
	Global.canvas.queue_redraw()


func _on_user_data_text_edit_text_changed() -> void:
	for layer_index in layer_indices:
		var layer := Global.current_project.layers[layer_index]
		layer.user_data = user_data_text_edit.text
