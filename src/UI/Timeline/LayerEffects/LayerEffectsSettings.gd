extends AcceptDialog

const LAYER_EFFECT_BUTTON = preload("res://src/UI/Timeline/LayerEffects/LayerEffectButton.gd")
const DELETE_TEXTURE := preload("res://assets/graphics/misc/close.svg")

var effects: Array[LayerEffect] = [
	LayerEffect.new(
		"Convolution Matrix", preload("res://src/Shaders/Effects/ConvolutionMatrix.gdshader")
	),
	LayerEffect.new("Gaussian Blur", preload("res://src/Shaders/Effects/GaussianBlur.gdshader")),
	LayerEffect.new("Offset", preload("res://src/Shaders/Effects/OffsetPixels.gdshader")),
	LayerEffect.new("Outline", preload("res://src/Shaders/Effects/OutlineInline.gdshader")),
	LayerEffect.new("Drop Shadow", preload("res://src/Shaders/Effects/DropShadow.gdshader")),
	LayerEffect.new("Invert Colors", preload("res://src/Shaders/Effects/Invert.gdshader")),
	LayerEffect.new("Desaturation", preload("res://src/Shaders/Effects/Desaturate.gdshader")),
	LayerEffect.new(
		"Adjust Hue/Saturation/Value", preload("res://src/Shaders/Effects/HSV.gdshader")
	),
	LayerEffect.new(
		"Adjust Brightness/Contrast",
		preload("res://src/Shaders/Effects/BrightnessContrast.gdshader")
	),
	LayerEffect.new("Palettize", preload("res://src/Shaders/Effects/Palettize.gdshader")),
	LayerEffect.new("Pixelize", preload("res://src/Shaders/Effects/Pixelize.gdshader")),
	LayerEffect.new("Posterize", preload("res://src/Shaders/Effects/Posterize.gdshader")),
	LayerEffect.new("Gradient Map", preload("res://src/Shaders/Effects/GradientMap.gdshader")),
	LayerEffect.new("Index Map", preload("res://src/Shaders/Effects/IndexMap.gdshader")),
]

@onready var enabled_button: CheckButton = $VBoxContainer/HBoxContainer/EnabledButton
@onready var effect_list: MenuButton = $VBoxContainer/HBoxContainer/EffectList
@onready var effect_container: VBoxContainer = $VBoxContainer/ScrollContainer/EffectContainer
@onready var drag_highlight: ColorRect = $DragHighlight


func _ready() -> void:
	for effect in effects:
		effect_list.get_popup().add_item(effect.name)
	effect_list.get_popup().id_pressed.connect(_on_effect_list_id_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drag_highlight.hide()


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
	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Add layer effect")
	Global.current_project.undo_redo.add_do_method(func(): layer.effects.append(effect))
	Global.current_project.undo_redo.add_do_method(Global.canvas.queue_redraw)
	Global.current_project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	Global.current_project.undo_redo.add_undo_method(func(): layer.effects.erase(effect))
	Global.current_project.undo_redo.add_undo_method(Global.canvas.queue_redraw)
	Global.current_project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	Global.current_project.undo_redo.commit_action()
	_create_effect_ui(layer, effect)


func _create_effect_ui(layer: BaseLayer, effect: LayerEffect) -> void:
	var panel_container := PanelContainer.new()
	var hbox := HBoxContainer.new()
	var enable_checkbox := CheckButton.new()
	enable_checkbox.button_pressed = effect.enabled
	enable_checkbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	enable_checkbox.toggled.connect(_enable_effect.bind(effect))
	var label := Label.new()
	label.text = effect.name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var delete_button := TextureButton.new()
	delete_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	delete_button.texture_normal = DELETE_TEXTURE
	delete_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	delete_button.add_to_group(&"UIButtons")
	delete_button.modulate = Global.modulate_icon_color
	delete_button.pressed.connect(_delete_effect.bind(effect))
	hbox.add_child(enable_checkbox)
	hbox.add_child(label)
	if layer is PixelLayer:
		var apply_button := Button.new()
		apply_button.text = "Apply"
		apply_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		apply_button.pressed.connect(_apply_effect.bind(layer, effect))
		hbox.add_child(apply_button)
	hbox.add_child(delete_button)
	var parameter_vbox := CollapsibleContainer.new()
	ShaderLoader.create_ui_for_shader_uniforms(
		effect.shader,
		effect.params,
		parameter_vbox,
		_set_parameter.bind(effect),
		_load_parameter_texture.bind(effect)
	)
	var collapsible_button := parameter_vbox.get_button()
	collapsible_button.set_script(LAYER_EFFECT_BUTTON)
	collapsible_button.layer = layer
	collapsible_button.layer_effects_settings = self
	collapsible_button.add_child(hbox)
	hbox.anchor_left = 0.05
	hbox.anchor_top = 0
	hbox.anchor_right = 0.99
	hbox.anchor_bottom = 1
	panel_container.add_child(parameter_vbox)
	effect_container.add_child(panel_container)
	parameter_vbox.set_visible_children(false)
	collapsible_button.custom_minimum_size.y = collapsible_button.size.y + 4


func _enable_effect(button_pressed: bool, effect: LayerEffect) -> void:
	effect.enabled = button_pressed
	Global.canvas.queue_redraw()


func move_effect(layer: BaseLayer, from_index: int, to_index: int) -> void:
	var layer_effect := layer.effects[from_index]
	layer.effects.remove_at(from_index)
	layer.effects.insert(to_index, layer_effect)


func _delete_effect(effect: LayerEffect) -> void:
	var layer := Global.current_project.layers[Global.current_project.current_layer]
	var index := layer.effects.find(effect)
	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Delete layer effect")
	Global.current_project.undo_redo.add_do_method(func(): layer.effects.erase(effect))
	Global.current_project.undo_redo.add_do_method(Global.canvas.queue_redraw)
	Global.current_project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	Global.current_project.undo_redo.add_undo_method(func(): layer.effects.insert(index, effect))
	Global.current_project.undo_redo.add_undo_method(Global.canvas.queue_redraw)
	Global.current_project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	Global.current_project.undo_redo.commit_action()
	effect_container.get_child(index).queue_free()


func _apply_effect(layer: BaseLayer, effect: LayerEffect) -> void:
	var index := layer.effects.find(effect)
	var redo_data := {}
	var undo_data := {}
	for frame in Global.current_project.frames:
		var cel := frame.cels[layer.index]
		var new_image := Image.new()
		new_image.copy_from(cel.get_image())
		var image_size := new_image.get_size()
		var shader_image_effect := ShaderImageEffect.new()
		shader_image_effect.generate_image(new_image, effect.shader, effect.params, image_size)
		redo_data[cel.image] = new_image.data
		undo_data[cel.image] = cel.image.data
	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Apply layer effect")
	Global.undo_redo_compress_images(redo_data, undo_data)
	Global.current_project.undo_redo.add_do_method(func(): layer.effects.erase(effect))
	Global.current_project.undo_redo.add_do_method(Global.canvas.queue_redraw)
	Global.current_project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	Global.current_project.undo_redo.add_undo_method(func(): layer.effects.insert(index, effect))
	Global.current_project.undo_redo.add_undo_method(Global.canvas.queue_redraw)
	Global.current_project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	Global.current_project.undo_redo.commit_action()
	effect_container.get_child(index).queue_free()


func _set_parameter(value, param: String, effect: LayerEffect) -> void:
	effect.params[param] = value
	Global.canvas.queue_redraw()


func _load_parameter_texture(path: String, param: String, effect: LayerEffect) -> void:
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
