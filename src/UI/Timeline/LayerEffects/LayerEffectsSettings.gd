extends AcceptDialog

const LAYER_EFFECT_BUTTON = preload("res://src/UI/Timeline/LayerEffects/LayerEffectButton.gd")
const DELETE_TEXTURE := preload("res://assets/graphics/misc/close.svg")

var effects: Array[LayerEffect] = [
	LayerEffect.new(
		"Convolution Matrix",
		preload("res://src/Shaders/Effects/ConvolutionMatrix.gdshader"),
		"Color"
	),
	LayerEffect.new(
		"Gaussian Blur", preload("res://src/Shaders/Effects/GaussianBlur.gdshader"), "Blur"
	),
	LayerEffect.new(
		"Offset", preload("res://src/Shaders/Effects/OffsetPixels.gdshader"), "Transform"
	),
	LayerEffect.new(
		"Outline", preload("res://src/Shaders/Effects/OutlineInline.gdshader"), "Procedural"
	),
	LayerEffect.new(
		"Drop Shadow", preload("res://src/Shaders/Effects/DropShadow.gdshader"), "Procedural"
	),
	LayerEffect.new("Invert Colors", preload("res://src/Shaders/Effects/Invert.gdshader"), "Color"),
	LayerEffect.new(
		"Desaturation", preload("res://src/Shaders/Effects/Desaturate.gdshader"), "Color"
	),
	LayerEffect.new(
		"Adjust Hue/Saturation/Value", preload("res://src/Shaders/Effects/HSV.gdshader"), "Color"
	),
	LayerEffect.new(
		"Adjust Brightness/Contrast",
		preload("res://src/Shaders/Effects/BrightnessContrast.gdshader"),
		"Color"
	),
	LayerEffect.new(
		"Color Curves", preload("res://src/Shaders/Effects/ColorCurves.gdshader"), "Color"
	),
	LayerEffect.new("Palettize", preload("res://src/Shaders/Effects/Palettize.gdshader"), "Color"),
	LayerEffect.new("Pixelize", preload("res://src/Shaders/Effects/Pixelize.gdshader"), "Blur"),
	LayerEffect.new("Posterize", preload("res://src/Shaders/Effects/Posterize.gdshader"), "Color"),
	LayerEffect.new(
		"Gradient Map", preload("res://src/Shaders/Effects/GradientMap.gdshader"), "Color"
	),
	LayerEffect.new("Index Map", preload("res://src/Shaders/Effects/IndexMap.gdshader"), "Color"),
]
## Dictionary of [String] and [PopupMenu], mapping each category to a PopupMenu.
var category_submenus := {}

@onready var enabled_button: CheckButton = $VBoxContainer/HBoxContainer/EnabledButton
@onready var effect_list: MenuButton = $VBoxContainer/HBoxContainer/EffectList
@onready var effect_container: VBoxContainer = $VBoxContainer/ScrollContainer/EffectContainer
@onready var drag_highlight: ColorRect = $DragHighlight


func _ready() -> void:
	var effect_list_popup := effect_list.get_popup()
	for i in effects.size():
		_add_effect_to_list(i)
	if not DirAccess.dir_exists_absolute(OpenSave.SHADERS_DIRECTORY):
		DirAccess.make_dir_recursive_absolute(OpenSave.SHADERS_DIRECTORY)
	for file_name in DirAccess.get_files_at(OpenSave.SHADERS_DIRECTORY):
		_load_shader_file(OpenSave.SHADERS_DIRECTORY.path_join(file_name))
	OpenSave.shader_copied.connect(_load_shader_file)
	effect_list_popup.index_pressed.connect(_on_effect_list_pressed.bind(effect_list_popup))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drag_highlight.hide()


func _on_about_to_popup() -> void:
	var layer := Global.current_project.layers[Global.current_project.current_layer]
	enabled_button.button_pressed = layer.effects_enabled
	for effect in layer.effects:
		if is_instance_valid(effect.shader):
			_create_effect_ui(layer, effect)


func _on_visibility_changed() -> void:
	if not visible:
		Global.dialog_open(false)
		for child in effect_container.get_children():
			child.queue_free()


func _add_effect_to_list(i: int) -> void:
	var effect_list_popup := effect_list.get_popup()
	var effect := effects[i]
	if effect.category.is_empty():
		effect_list_popup.add_item(effect.name)
		effect_list_popup.set_item_metadata(effect_list_popup.item_count - 1, i)
	else:
		if category_submenus.has(effect.category):
			var submenu := category_submenus[effect.category] as PopupMenu
			submenu.add_item(effect.name)
			submenu.set_item_metadata(submenu.item_count - 1, i)
		else:
			var submenu := PopupMenu.new()
			effect_list_popup.add_submenu_node_item(effect.category, submenu)
			submenu.add_item(effect.name)
			submenu.set_item_metadata(submenu.item_count - 1, i)
			submenu.index_pressed.connect(_on_effect_list_pressed.bind(submenu))
			category_submenus[effect.category] = submenu


func _load_shader_file(file_path: String) -> void:
	var file := load(file_path)
	if file is Shader:
		var effect_name := file_path.get_file().get_basename()
		var new_effect := LayerEffect.new(effect_name, file, "Loaded")
		effects.append(new_effect)
		_add_effect_to_list(effects.size() - 1)
		#effect_list.get_popup().add_item(effect_name)


func _on_effect_list_pressed(menu_item_index: int, menu: PopupMenu) -> void:
	var index: int = menu.get_item_metadata(menu_item_index)
	var layer := Global.current_project.layers[Global.current_project.current_layer]
	var effect := effects[index].duplicate()
	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Add layer effect")
	Global.current_project.undo_redo.add_do_method(func(): layer.effects.append(effect))
	Global.current_project.undo_redo.add_do_method(layer.emit_effects_added_removed)
	Global.current_project.undo_redo.add_do_method(Global.canvas.queue_redraw)
	Global.current_project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	Global.current_project.undo_redo.add_undo_method(func(): layer.effects.erase(effect))
	Global.current_project.undo_redo.add_undo_method(layer.emit_effects_added_removed)
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
	Global.current_project.undo_redo.add_do_method(layer.emit_effects_added_removed)
	Global.current_project.undo_redo.add_do_method(Global.canvas.queue_redraw)
	Global.current_project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	Global.current_project.undo_redo.add_undo_method(func(): layer.effects.insert(index, effect))
	Global.current_project.undo_redo.add_undo_method(layer.emit_effects_added_removed)
	Global.current_project.undo_redo.add_undo_method(Global.canvas.queue_redraw)
	Global.current_project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	Global.current_project.undo_redo.commit_action()
	effect_container.get_child(index).queue_free()


func _apply_effect(layer: BaseLayer, effect: LayerEffect) -> void:
	var project := Global.current_project
	var index := layer.effects.find(effect)
	var redo_data := {}
	var undo_data := {}
	for i in project.frames.size():
		var frame := project.frames[i]
		var cel := frame.cels[layer.index]
		var cel_image := cel.get_image()
		if cel is CelTileMap:
			undo_data[cel] = (cel as CelTileMap).serialize_undo_data()
		if cel_image is ImageExtended:
			undo_data[cel_image.indices_image] = cel_image.indices_image.data
		undo_data[cel_image] = cel_image.data
		var image_size := cel_image.get_size()
		var params := effect.params
		params["PXO_time"] = frame.position_in_seconds(project)
		params["PXO_frame_index"] = i
		params["PXO_layer_index"] = layer.index
		var shader_image_effect := ShaderImageEffect.new()
		shader_image_effect.generate_image(cel_image, effect.shader, params, image_size)

	var tile_editing_mode := TileSetPanel.tile_editing_mode
	if tile_editing_mode == TileSetPanel.TileEditingMode.MANUAL:
		tile_editing_mode = TileSetPanel.TileEditingMode.AUTO
	project.update_tilemaps(undo_data, tile_editing_mode)
	for frame in project.frames:
		var cel := frame.cels[layer.index]
		var cel_image := cel.get_image()
		if cel is CelTileMap:
			redo_data[cel] = (cel as CelTileMap).serialize_undo_data()
		if cel_image is ImageExtended:
			redo_data[cel_image.indices_image] = cel_image.indices_image.data
		redo_data[cel_image] = cel_image.data
	project.undos += 1
	project.undo_redo.create_action("Apply layer effect")
	project.deserialize_cel_undo_data(redo_data, undo_data)
	project.undo_redo.add_do_method(func(): layer.effects.erase(effect))
	project.undo_redo.add_do_method(Global.canvas.queue_redraw)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(func(): layer.effects.insert(index, effect))
	project.undo_redo.add_undo_method(Global.canvas.queue_redraw)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()
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
