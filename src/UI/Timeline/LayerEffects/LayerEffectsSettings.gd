extends AcceptDialog

const DELETE_TEXTURE := preload("res://assets/graphics/misc/close.svg")
const MOVE_UP_TEXTURE := preload("res://assets/graphics/misc/move_up_arrow.svg")
const MOVE_DOWN_TEXTURE := preload("res://assets/graphics/misc/move_down_arrow.svg")

var effects: Array[LayerEffect] = [
	LayerEffect.new("Offset", preload("res://src/Shaders/Effects/OffsetPixels.gdshader")),
	LayerEffect.new("Outline", preload("res://src/Shaders/Effects/OutlineInline.gdshader")),
	LayerEffect.new("Drop Shadow", preload("res://src/Shaders/Effects/DropShadow.gdshader")),
	LayerEffect.new("Invert Colors", preload("res://src/Shaders/Effects/Invert.gdshader")),
	LayerEffect.new("Desaturation", preload("res://src/Shaders/Effects/Desaturate.gdshader")),
	LayerEffect.new(
		"Adjust Hue/Saturation/Value", preload("res://src/Shaders/Effects/HSV.gdshader")
	),
	LayerEffect.new("Posterize", preload("res://src/Shaders/Effects/Posterize.gdshader")),
	LayerEffect.new("Gradient Map", preload("res://src/Shaders/Effects/GradientMap.gdshader")),
]

@onready var enabled_button: CheckButton = $VBoxContainer/HBoxContainer/EnabledButton
@onready var effect_list: MenuButton = $VBoxContainer/HBoxContainer/EffectList
@onready var effect_container: VBoxContainer = $VBoxContainer/ScrollContainer/EffectContainer


func _ready() -> void:
	for effect in effects:
		effect_list.get_popup().add_item(effect.name)
	effect_list.get_popup().id_pressed.connect(_on_effect_list_id_pressed)


func _on_about_to_popup() -> void:
	var layer := Global.current_project.layers[Global.current_project.current_layer]
	enabled_button.button_pressed = layer.effects_enabled
	for effect in layer.effects:
		_create_effect_ui(layer, effect)


func _on_visibility_changed() -> void:
	if not visible:
		Global.dialog_open(false)
		for child in effect_container.get_children():
			child.queue_free()


func _on_effect_list_id_pressed(index: int) -> void:
	var layer := Global.current_project.layers[Global.current_project.current_layer]
	var effect := effects[index].duplicate()
	_create_effect_ui(layer, effect)
	layer.effects.append(effect)
	Global.canvas.queue_redraw()


func _create_effect_ui(layer: BaseLayer, effect: LayerEffect) -> void:
	var panel_container := PanelContainer.new()
	var vbox := VBoxContainer.new()
	var hbox := HBoxContainer.new()
	var enable_checkbox := CheckButton.new()
	enable_checkbox.button_pressed = effect.enabled
	enable_checkbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	enable_checkbox.toggled.connect(_enable_effect.bind(effect))
	var label := Label.new()
	label.text = effect.name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var move_up_button := TextureButton.new()
	move_up_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	move_up_button.texture_normal = MOVE_UP_TEXTURE
	move_up_button.add_to_group(&"UIButtons")
	move_up_button.modulate = Global.modulate_icon_color
	move_up_button.pressed.connect(_re_order_effect.bind(effect, layer, panel_container, -1))
	var move_down_button := TextureButton.new()
	move_down_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	move_down_button.texture_normal = MOVE_DOWN_TEXTURE
	move_down_button.add_to_group(&"UIButtons")
	move_down_button.modulate = Global.modulate_icon_color
	move_down_button.pressed.connect(_re_order_effect.bind(effect, layer, panel_container, 1))
	var delete_button := TextureButton.new()
	delete_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	delete_button.texture_normal = DELETE_TEXTURE
	delete_button.add_to_group(&"UIButtons")
	delete_button.modulate = Global.modulate_icon_color
	delete_button.pressed.connect(_delete_effect.bind(effect))
	hbox.add_child(enable_checkbox)
	hbox.add_child(label)
	hbox.add_child(move_up_button)
	hbox.add_child(move_down_button)
	hbox.add_child(delete_button)
	var parameter_vbox := CollapsibleContainer.new()
	parameter_vbox.text = "Options"
	Global.create_ui_for_shader_uniforms(
		effect.shader,
		effect.params,
		parameter_vbox,
		_set_parameter.bind(effect),
		_load_parameter_texture.bind(effect)
	)
	vbox.add_child(hbox)
	vbox.add_child(parameter_vbox)
	panel_container.add_child(vbox)
	effect_container.add_child(panel_container)
	parameter_vbox.set_visible_children(false)


func _enable_effect(button_pressed: bool, effect: LayerEffect) -> void:
	effect.enabled = button_pressed
	Global.canvas.queue_redraw()


func _re_order_effect(
	effect: LayerEffect, layer: BaseLayer, container: Container, direction: int
) -> void:
	assert(layer.effects.size() == effect_container.get_child_count())
	var effect_index := container.get_index()
	var new_index := effect_index + direction
	if new_index < 0:
		return
	if new_index >= effect_container.get_child_count():
		return
	effect_container.move_child(container, new_index)
	var temp := layer.effects[new_index]
	layer.effects[new_index] = effect
	layer.effects[effect_index] = temp
	Global.canvas.queue_redraw()


func _delete_effect(effect: LayerEffect) -> void:
	var layer := Global.current_project.layers[Global.current_project.current_layer]
	var index := layer.effects.find(effect)
	effect_container.get_child(index).queue_free()
	layer.effects.remove_at(index)
	Global.canvas.queue_redraw()


func _set_parameter(value, param: String, effect: LayerEffect) -> void:
	effect.params[param] = value
	Global.canvas.queue_redraw()


func _load_parameter_texture(path: String, effect: LayerEffect, param: String) -> void:
	var image := Image.new()
	image.load(path)
	if !image:
		print("Error loading texture")
		return
	var image_tex := ImageTexture.create_from_image(image)
	_set_parameter(image_tex, param, effect)


func _on_enabled_button_toggled(button_pressed: bool) -> void:
	var layer := Global.current_project.layers[Global.current_project.current_layer]
	layer.effects_enabled = button_pressed
	Global.canvas.queue_redraw()
