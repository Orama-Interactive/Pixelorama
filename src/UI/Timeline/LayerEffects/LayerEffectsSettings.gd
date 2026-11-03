class_name LayerFXPanel
extends PanelContainer

const DELETE_TEXTURE := preload("res://assets/graphics/misc/close.svg")

var effects: Array[LayerEffect] = [
	LayerEffect.new(
		"Offset & Scale", load("res://src/Shaders/Effects/OffsetPixels.gdshaderinc"), "Transform"
	),
	LayerEffect.new(
		"Corner Pin", load("res://src/Shaders/Effects/CornerPin.gdshaderinc"), "Transform"
	),
	LayerEffect.new(
		"Flat to Isometric",
		load("res://src/Shaders/Effects/FlatToIsometric.gdshaderinc"),
		"Transform"
	),
	LayerEffect.new(
		"Convolution Matrix",
		load("res://src/Shaders/Effects/ConvolutionMatrix.gdshaderinc"),
		"Color"
	),
	LayerEffect.new(
		"Gaussian Blur", load("res://src/Shaders/Effects/GaussianBlur.gdshaderinc"), "Blur"
	),
	LayerEffect.new(
		"Gradient", load("res://src/Shaders/Effects/Gradient.gdshaderinc"), "Procedural"
	),
	LayerEffect.new(
		"Outline", load("res://src/Shaders/Effects/OutlineInline.gdshaderinc"), "Procedural"
	),
	LayerEffect.new(
		"Drop Shadow", load("res://src/Shaders/Effects/DropShadow.gdshaderinc"), "Procedural"
	),
	LayerEffect.new("Invert Colors", load("res://src/Shaders/Effects/Invert.gdshaderinc"), "Color"),
	LayerEffect.new(
		"Desaturation", load("res://src/Shaders/Effects/Desaturate.gdshaderinc"), "Color"
	),
	LayerEffect.new(
		"Adjust Hue/Saturation/Value", load("res://src/Shaders/Effects/HSV.gdshaderinc"), "Color"
	),
	LayerEffect.new(
		"Adjust Brightness/Contrast",
		load("res://src/Shaders/Effects/BrightnessContrast.gdshaderinc"),
		"Color"
	),
	LayerEffect.new(
		"Color Curves", load("res://src/Shaders/Effects/ColorCurves.gdshaderinc"), "Color"
	),
	LayerEffect.new("Luma", load("res://src/Shaders/Effects/Luma.gdshaderinc"), "Color"),
	LayerEffect.new("Palettize", load("res://src/Shaders/Effects/Palettize.gdshaderinc"), "Color"),
	LayerEffect.new("Pixelize", load("res://src/Shaders/Effects/Pixelize.gdshaderinc"), "Blur"),
	LayerEffect.new("Posterize", load("res://src/Shaders/Effects/Posterize.gdshaderinc"), "Color"),
	LayerEffect.new(
		"Gradient Map", load("res://src/Shaders/Effects/GradientMap.gdshaderinc"), "Color"
	),
	LayerEffect.new("Index Map", load("res://src/Shaders/Effects/IndexMap.gdshader"), "Color"),
]
var current_layer: BaseLayer
## A dictionary that maps each category to a [PopupMenu].
var category_submenus: Dictionary[String, PopupMenu] = {}

@onready var enabled_button: CheckButton = %EnabledButton
@onready var effect_list: MenuButton = $MarginContainer/VBoxContainer/HBoxContainer/EffectList
@onready var effect_container: VBoxContainer = %EffectContainer
@onready var drag_highlight: ColorRect = $DragHighlight


func _ready() -> void:
	var effect_list_popup := effect_list.get_popup()
	for i in effects.size():
		_add_effect_to_list(i)
	if not DirAccess.dir_exists_absolute(OpenSave.SHADERS_DIRECTORY):
		DirAccess.make_dir_recursive_absolute(OpenSave.SHADERS_DIRECTORY)
	for file_name in DirAccess.get_files_at(OpenSave.SHADERS_DIRECTORY):
		_load_shader_file(OpenSave.SHADERS_DIRECTORY.path_join(file_name))
	Global.cel_switched.connect(_on_cel_switched)
	OpenSave.shader_copied.connect(_load_shader_file)
	effect_list_popup.index_pressed.connect(_on_effect_list_pressed.bind(effect_list_popup))
	await get_tree().process_frame
	_on_cel_switched()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drag_highlight.hide()


func _on_cel_switched() -> void:
	for connection in get_incoming_connections():
		if connection.callable.get_method() == "_on_keyframe_changed":
			connection.signal.disconnect(_on_keyframe_changed)
	var layer := Global.current_project.layers[Global.current_project.current_layer]
	if layer != current_layer:
		for child in effect_container.get_children():
			child.queue_free()
		enabled_button.button_pressed = layer.effects_enabled
		for effect in layer.effects:
			if is_instance_valid(effect.shader):
				_add_effect_node(layer, effect)

	current_layer = layer

	for i in layer.effects.size():
		var effect := layer.effects[i]
		if not effect.keyframe_set.is_connected(_on_keyframe_changed):
			effect.keyframe_set.connect(_on_keyframe_changed.bind(effect, i))
			effect.keyframe_unset.connect(_on_keyframe_changed.bind(effect, i))
		var effect_param_container := effect_container.get_child(i).get_child(0)
		_set_proper_keyframe_texture(effect, effect_param_container)


func _set_proper_keyframe_texture(effect: LayerEffect, effect_param_container: Control) -> void:
	var frame_index := Global.current_project.current_frame
	for j in range(0, effect_param_container.get_child_count()):
		var hbox := effect_param_container.get_child(j)
		# NOTE: there is no guarantee that hbox is an HBoxContainer, for example in Index map effect
		# a FileDialog is also child of effect_param_container, so we need to verify the type.
		if not hbox is HBoxContainer:
			continue
		var param_node := hbox.get_child(1)
		if param_node is Container and not param_node is BasisSliders:
			param_node = param_node.get_child(0)
		var keyframe_button: Node
		if hbox.get_child_count() > 2:
			keyframe_button = hbox.get_child(2)
		if param_node.name in effect.animated_params:
			var value = effect.get_params(frame_index)[param_node.name]
			Global.set_value_to_node(param_node, value)
			effect.params[param_node.name] = value
			if keyframe_button is TextureButton:
				ShaderLoader.get_proper_keyframe_texture(keyframe_button, effect, param_node.name)
				keyframe_button.self_modulate = Color.WHITE


func _add_effect_to_list(i: int) -> void:
	var effect_list_popup := effect_list.get_popup()
	var effect := effects[i]
	if effect.category.is_empty():
		effect_list_popup.add_item(effect.name)
		effect_list_popup.set_item_metadata(effect_list_popup.item_count - 1, i)
	else:
		if category_submenus.has(effect.category):
			var submenu := category_submenus[effect.category]
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


func _on_effect_list_pressed(menu_item_index: int, menu: PopupMenu) -> void:
	var index: int = menu.get_item_metadata(menu_item_index)
	var project := Global.current_project
	var layer := project.layers[project.current_layer]
	var effect := effects[index].duplicate()
	effect.layer = layer
	project.undo_redo.create_action("Add layer effect")
	project.undo_redo.add_do_method(layer.add_effect.bind(effect))
	project.undo_redo.add_do_method(_add_effect_node.bind(layer, effect))
	# we may be a different layer during redo
	project.undo_redo.add_do_property(Global.canvas, "mandatory_update_layers", [layer.index])
	project.undo_redo.add_do_method(Global.canvas.queue_redraw)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(layer.remove_effect.bind(effect))
	project.undo_redo.add_undo_method(_remove_effect_node)
	# we may be a different layer during undo
	project.undo_redo.add_undo_property(Global.canvas, "mandatory_update_layers", [layer.index])
	project.undo_redo.add_undo_method(Global.canvas.queue_redraw)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func _create_effect_node(layer: BaseLayer, effect: LayerEffect) -> Node:
	var foldable_container := LayerEffectFoldable.new()
	foldable_container.title = effect.name
	var enable_checkbox := CheckButton.new()
	enable_checkbox.button_pressed = effect.enabled
	enable_checkbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	enable_checkbox.toggled.connect(_enable_effect.bind(effect))
	var delete_button := TextureButton.new()
	delete_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	delete_button.texture_normal = DELETE_TEXTURE
	delete_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	delete_button.add_to_group(&"UIButtons")
	delete_button.modulate = Global.modulate_icon_color
	delete_button.pressed.connect(_delete_effect.bind(effect))
	foldable_container.add_title_bar_control(enable_checkbox)
	if layer is PixelLayer:
		var apply_button := Button.new()
		apply_button.text = "Apply"
		apply_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		apply_button.pressed.connect(_apply_effect.bind(layer, effect))
		foldable_container.add_title_bar_control(apply_button)
	foldable_container.add_title_bar_control(delete_button)
	var parameter_vbox := VBoxContainer.new()
	ShaderLoader.create_ui_for_shader_uniforms(
		effect.shader,
		effect.params,
		effect.param_properties,
		parameter_vbox,
		_set_parameter.bind(effect, layer),
		_load_parameter_texture.bind(effect, layer),
		_on_keyframe_pressed.bind(effect)
	)
	foldable_container.layer = layer
	foldable_container.parent_panel = self
	foldable_container.add_child(parameter_vbox)
	foldable_container.fold()
	_set_proper_keyframe_texture(effect, parameter_vbox)
	return foldable_container


func _add_effect_node(layer: BaseLayer, effect: LayerEffect, to_index := -1) -> void:
	var node := _create_effect_node(layer, effect)
	effect_container.add_child(node)
	if to_index != -1:
		effect_container.move_child(node, to_index)
	if not effect.keyframe_set.is_connected(_on_keyframe_changed):
		var effect_index := layer.effects.find(effect)
		effect.keyframe_set.connect(_on_keyframe_changed.bind(effect, effect_index))
		effect.keyframe_unset.connect(_on_keyframe_changed.bind(effect, effect_index))


func _remove_effect_node(child_index := -1) -> void:
	effect_container.get_child(child_index).queue_free()


func _move_effect_node(from_index: int, to_index: int) -> void:
	var drop_panel := effect_container.get_child(from_index)
	effect_container.move_child(drop_panel, to_index)


func _enable_effect(button_pressed: bool, effect: LayerEffect) -> void:
	effect.enabled = button_pressed
	Global.canvas.queue_redraw()


func move_effect(layer: BaseLayer, from_index: int, to_index: int) -> void:
	var project := layer.project
	var layer_effect := layer.effects[from_index]

	project.undo_redo.create_action("Re-arrange layer effect")
	project.undo_redo.add_do_method(layer.move_effect.bind(layer_effect, to_index))
	project.undo_redo.add_do_method(_move_effect_node.bind(from_index, to_index))
	project.undo_redo.add_do_method(Global.canvas.queue_redraw)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(layer.move_effect.bind(layer_effect, from_index))
	project.undo_redo.add_undo_method(_move_effect_node.bind(to_index, from_index))
	project.undo_redo.add_undo_method(Global.canvas.queue_redraw)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func _delete_effect(effect: LayerEffect) -> void:
	var layer := effect.layer
	var project := layer.project
	var index := layer.effects.find(effect)
	project.undo_redo.create_action("Delete layer effect")
	project.undo_redo.add_do_method(layer.remove_effect.bind(effect))
	project.undo_redo.add_do_method(_remove_effect_node.bind(index))
	# we may be a different layer during redo
	project.undo_redo.add_do_property(Global.canvas, "mandatory_update_layers", [layer.index])
	project.undo_redo.add_do_method(Global.canvas.queue_redraw)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(layer.add_effect.bind(effect, index))
	project.undo_redo.add_undo_method(_add_effect_node.bind(layer, effect, index))
	# we may be a different layer during undo
	project.undo_redo.add_undo_property(Global.canvas, "mandatory_update_layers", [layer.index])
	project.undo_redo.add_undo_method(Global.canvas.queue_redraw)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func _apply_effect(layer: BaseLayer, effect: LayerEffect) -> void:
	Global.transform_content_confirmed.emit()
	var project := layer.project
	var index := layer.effects.find(effect)
	var redo_data := {}
	var undo_data := {}
	for i in project.frames.size():
		var frame := project.frames[i]
		var cel := frame.cels[layer.index]
		undo_data[cel] = {"offset": cel.offset}
		if cel is CelTileMap:
			if cel.place_only_mode:
				continue
			undo_data[cel] = (cel as CelTileMap).serialize_undo_data()
		var cel_image := cel.get_image()
		if cel_image is ImageExtended:
			undo_data[cel_image.indices_image] = cel_image.indices_image.data
		undo_data[cel_image] = cel_image.data
		var params := effect.get_params(i)
		params["PXO_time"] = frame.position_in_seconds(project)
		params["PXO_frame_index"] = i
		params["PXO_layer_index"] = layer.index
		var effect_image: Image
		if layer.use_cel_image_for_effects:
			effect_image = cel.get_image()
		else:
			effect_image = project.crop_image_to_project_size(cel.get_image(), cel.offset)
		var image_size := effect_image.get_size()
		var shader_image_effect := ShaderImageEffect.new()
		shader_image_effect.generate_image(effect_image, effect.shader, params, image_size)
		if not layer.use_cel_image_for_effects:
			cel.blit_image_to_cel(effect_image)

	var tile_editing_mode := TileSetPanel.tile_editing_mode
	if tile_editing_mode == TileSetPanel.TileEditingMode.MANUAL:
		tile_editing_mode = TileSetPanel.TileEditingMode.AUTO
	var used_tilesets := project.update_tilemaps(undo_data, tile_editing_mode)
	for frame in project.frames:
		var cel := frame.cels[layer.index]
		var cel_image := cel.get_image()
		redo_data[cel] = {"offset": cel.offset}
		if cel is CelTileMap:
			redo_data[cel] = (cel as CelTileMap).serialize_undo_data()
		if cel_image is ImageExtended:
			redo_data[cel_image.indices_image] = cel_image.indices_image.data
		redo_data[cel_image] = cel_image.data
	project.undo_redo.create_action("Apply layer effect")
	var layers_to_update := PackedInt32Array()
	for l in project.layers:
		if l is LayerTileMap:
			if l.tileset in used_tilesets:
				layers_to_update.append(l.index)
	project.deserialize_cel_undo_data(redo_data, undo_data)
	# we may be on a different layer during undo/redo
	project.undo_redo.add_do_property(Global.canvas, "mandatory_update_layers", layers_to_update)
	project.undo_redo.add_undo_property(Global.canvas, "mandatory_update_layers", layers_to_update)
	project.undo_redo.add_do_method(layer.remove_effect.bind(effect))
	project.undo_redo.add_do_method(_remove_effect_node.bind(index))
	# we may be a different layer during redo
	project.undo_redo.add_do_property(Global.canvas, "mandatory_update_layers", [layer.index])
	project.undo_redo.add_do_method(Global.canvas.queue_redraw)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(layer.add_effect.bind(effect, index))
	project.undo_redo.add_undo_method(_add_effect_node.bind(layer, effect, index))
	# we may be a different layer during undo
	project.undo_redo.add_undo_property(Global.canvas, "mandatory_update_layers", [layer.index])
	project.undo_redo.add_undo_method(Global.canvas.queue_redraw)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func _set_parameter(value, param: String, effect: LayerEffect, layer: BaseLayer) -> void:
	effect.params[param] = value
	Global.canvas.queue_redraw()

	# Set the keyframe button to orange if the user makes a temporary change.
	var frame_index := layer.project.current_frame
	# Sanity check: When the effect UI is being created this check will trigger a return
	if layer.effects.size() != effect_container.get_child_count():
		return
	if not effect.animated_params.has(param):
		return
	var effect_index := layer.effects.find(effect)
	var effect_param_container := effect_container.get_child(effect_index).get_child(0)
	for i in range(0, effect_param_container.get_child_count()):
		var hbox := effect_param_container.get_child(i)
		if hbox.get_child_count() <= 2:
			continue
		var param_node := hbox.get_child(1)
		if param_node is Container and not param_node is BasisSliders:
			param_node = param_node.get_child(0)
		if param_node.name != param:
			continue
		var keyframe_button := hbox.get_child(2)
		if keyframe_button is not TextureButton:
			continue
		if value != effect.get_animated_property(frame_index, param):
			keyframe_button.self_modulate = Color.ORANGE
		else:
			keyframe_button.self_modulate = Color.WHITE


func _load_parameter_texture(
	path: String, param: String, effect: LayerEffect, layer: BaseLayer
) -> void:
	var image := Image.new()
	image.load(path)
	if not image:
		print("Error loading texture")
		return
	var image_tex := ImageTexture.create_from_image(image)
	_set_parameter(image_tex, param, effect, layer)


func _on_keyframe_pressed(param: String, effect: LayerEffect) -> void:
	var project := Global.current_project
	effect.add_keyframe_undo_redo(param, project.current_frame, project, effect.params[param])


## Needed for the keyframe buttons to update visually with undo/redo.
func _on_keyframe_changed(param_name: String, effect: LayerEffect, effect_index: int) -> void:
	var effect_param_container := effect_container.get_child(effect_index).get_child(0)
	for i in range(0, effect_param_container.get_child_count()):
		var hbox := effect_param_container.get_child(i)
		if hbox.get_child_count() <= 2:
			continue
		var param_node := hbox.get_child(1)
		if param_node is Container and not param_node is BasisSliders:
			param_node = param_node.get_child(0)
		if param_node.name != param_name:
			continue
		var keyframe_button = hbox.get_child(2)
		if keyframe_button is not TextureButton:
			continue
		ShaderLoader.get_proper_keyframe_texture(keyframe_button, effect, param_node.name)
		keyframe_button.self_modulate = Color.WHITE


func _on_enabled_button_toggled(button_pressed: bool) -> void:
	var layer := Global.current_project.layers[Global.current_project.current_layer]
	layer.effects_enabled = button_pressed
	Global.canvas.queue_redraw()
