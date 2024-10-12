extends AcceptDialog

signal layer_property_changed

var layer_indices: PackedInt32Array

@onready var name_line_edit := $GridContainer/NameLineEdit as LineEdit
@onready var opacity_slider := $GridContainer/OpacitySlider as ValueSlider
@onready var blend_modes_button := $GridContainer/BlendModeOptionButton as OptionButton
@onready var user_data_text_edit := $GridContainer/UserDataTextEdit as TextEdit


func _on_visibility_changed() -> void:
	if layer_indices.size() == 0:
		return
	Global.dialog_open(visible)
	var first_layer := Global.current_project.layers[layer_indices[0]]
	if visible:
		_fill_blend_modes_option_button()
		name_line_edit.text = first_layer.name
		opacity_slider.value = first_layer.opacity * 100.0
		var blend_mode_index := blend_modes_button.get_item_index(first_layer.blend_mode)
		blend_modes_button.selected = blend_mode_index
		user_data_text_edit.text = first_layer.user_data
	else:
		layer_indices = []


## Fill the blend modes OptionButton with items
func _fill_blend_modes_option_button() -> void:
	blend_modes_button.clear()
	var selected_layers_are_groups := true
	for layer_index in layer_indices:
		var layer := Global.current_project.layers[layer_index]
		if not layer is GroupLayer:
			selected_layers_are_groups = false
			break
	if selected_layers_are_groups:
		# Special blend mode that appears only when group layers are selected
		blend_modes_button.add_item("Pass through", BaseLayer.BlendModes.PASS_THROUGH)
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
	blend_modes_button.add_item("Subtract (RGB)", BaseLayer.BlendModes.SUBTRACT_RGB)
	blend_modes_button.add_item("Subtract (Alpha)", BaseLayer.BlendModes.SUBTRACT_ALPHA)
	blend_modes_button.add_item("Divide", BaseLayer.BlendModes.DIVIDE)
	blend_modes_button.add_item("Hue", BaseLayer.BlendModes.HUE)
	blend_modes_button.add_item("Saturation", BaseLayer.BlendModes.SATURATION)
	blend_modes_button.add_item("Color", BaseLayer.BlendModes.COLOR)
	blend_modes_button.add_item("Luminosity", BaseLayer.BlendModes.LUMINOSITY)


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
	_emit_layer_property_signal()
	Global.canvas.update_all_layers = true
	Global.canvas.queue_redraw()


func _on_blend_mode_option_button_item_selected(index: BaseLayer.BlendModes) -> void:
	if layer_indices.size() == 0:
		return
	Global.canvas.update_all_layers = true
	var project := Global.current_project
	var current_mode := blend_modes_button.get_item_id(index)
	project.undo_redo.create_action("Set Blend Mode")
	for layer_index in layer_indices:
		var layer := project.layers[layer_index]
		var previous_mode := layer.blend_mode
		project.undo_redo.add_do_property(layer, "blend_mode", current_mode)
		project.undo_redo.add_undo_property(layer, "blend_mode", previous_mode)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_do_method(Global.canvas.draw_layers)
	project.undo_redo.add_do_method(_emit_layer_property_signal)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_undo_method(Global.canvas.draw_layers)
	project.undo_redo.add_undo_method(_emit_layer_property_signal)
	project.undo_redo.commit_action()


func _on_user_data_text_edit_text_changed() -> void:
	for layer_index in layer_indices:
		var layer := Global.current_project.layers[layer_index]
		layer.user_data = user_data_text_edit.text


func _emit_layer_property_signal() -> void:
	layer_property_changed.emit()
