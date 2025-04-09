extends AcceptDialog

signal layer_property_changed

var layer_indices: PackedInt32Array

@onready var grid_container: GridContainer = $GridContainer
@onready var name_line_edit := $GridContainer/NameLineEdit as LineEdit
@onready var opacity_slider := $GridContainer/OpacitySlider as ValueSlider
@onready var blend_modes_button := $GridContainer/BlendModeOptionButton as OptionButton
@onready var play_at_frame_slider := $GridContainer/PlayAtFrameSlider as ValueSlider
@onready var user_data_text_edit := $GridContainer/UserDataTextEdit as TextEdit
@onready var ui_color_picker_button := $GridContainer/UIColorPickerButton as ColorPickerButton
@onready var tileset_option_button := $GridContainer/TilesetOptionButton as OptionButton
@onready var place_only_mode_check_button := $GridContainer/PlaceOnlyModeCheckButton as CheckButton
@onready var tile_size_slider: ValueSliderV2 = $GridContainer/TileSizeSlider
@onready var tile_shape_option_button: OptionButton = $GridContainer/TileShapeOptionButton
@onready var tile_layout_option_button: OptionButton = $GridContainer/TileLayoutOptionButton
@onready var tile_offset_axis_button: OptionButton = $GridContainer/TileOffsetAxisButton
@onready var audio_file_dialog := $AudioFileDialog as FileDialog
@onready var place_only_confirmation_dialog: ConfirmationDialog = $PlaceOnlyConfirmationDialog


func _ready() -> void:
	audio_file_dialog.use_native_dialog = Global.use_native_file_dialogs
	for dialog_child in audio_file_dialog.find_children("", "Window", true, false):
		if dialog_child is Window:
			dialog_child.always_on_top = audio_file_dialog.always_on_top


func _on_visibility_changed() -> void:
	if layer_indices.size() == 0:
		return
	Global.dialog_open(visible)
	var project := Global.current_project
	var first_layer := project.layers[layer_indices[0]]
	if visible:
		_fill_blend_modes_option_button()
		name_line_edit.text = first_layer.name
		opacity_slider.value = first_layer.opacity * 100.0
		var blend_mode_index := blend_modes_button.get_item_index(first_layer.blend_mode)
		blend_modes_button.selected = blend_mode_index
		if first_layer is AudioLayer:
			play_at_frame_slider.value = first_layer.playback_frame + 1
		play_at_frame_slider.max_value = project.frames.size()
		user_data_text_edit.text = first_layer.user_data
		ui_color_picker_button.color = first_layer.ui_color
		get_tree().set_group(&"VisualLayers", "visible", first_layer is not AudioLayer)
		get_tree().set_group(&"TilemapLayers", "visible", first_layer is LayerTileMap)
		get_tree().set_group(&"AudioLayers", "visible", first_layer is AudioLayer)
		var place_only_tilemap: bool = first_layer is LayerTileMap and first_layer.place_only_mode
		place_only_mode_check_button.disabled = place_only_tilemap
		get_tree().set_group(&"TilemapLayersPlaceOnly", "visible", place_only_tilemap)
		tileset_option_button.clear()
		if first_layer is LayerTileMap:
			for i in project.tilesets.size():
				var tileset := project.tilesets[i]
				tileset_option_button.add_item(tileset.get_text_info(i))
				if tileset == first_layer.tileset:
					tileset_option_button.select(i)
			place_only_mode_check_button.set_pressed_no_signal(first_layer.place_only_mode)
			tile_size_slider.set_value_no_signal(first_layer.tile_size)
			tile_shape_option_button.selected = first_layer.tile_shape
			tile_layout_option_button.selected = first_layer.tile_layout
			tile_offset_axis_button.selected = first_layer.tile_offset_axis
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
	blend_modes_button.add_item("Erase", BaseLayer.BlendModes.ERASE)
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
	project.undos += 1
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


func _on_ui_color_picker_button_color_changed(color: Color) -> void:
	for layer_index in layer_indices:
		var layer := Global.current_project.layers[layer_index]
		layer.ui_color = color


func _emit_layer_property_signal() -> void:
	layer_property_changed.emit()


func _on_tileset_option_button_item_selected(index: int) -> void:
	var project := Global.current_project
	var new_tileset := project.tilesets[index]
	project.undos += 1
	project.undo_redo.create_action("Set Tileset")
	for layer_index in layer_indices:
		var layer := project.layers[layer_index]
		if layer is not LayerTileMap:
			continue
		var previous_tileset := (layer as LayerTileMap).tileset
		project.undo_redo.add_do_method(layer.set_tileset.bind(new_tileset))
		project.undo_redo.add_undo_method(layer.set_tileset.bind(previous_tileset))
		for frame in project.frames:
			for i in frame.cels.size():
				var cel := frame.cels[i]
				if cel is CelTileMap and i == layer_index:
					project.undo_redo.add_do_method(cel.set_tileset.bind(new_tileset, false))
					project.undo_redo.add_do_method(cel.update_cel_portions)
					project.undo_redo.add_undo_method(cel.set_tileset.bind(previous_tileset, false))
					project.undo_redo.add_undo_method(cel.update_cel_portions)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_do_method(Global.canvas.draw_layers)
	project.undo_redo.add_do_method(func(): Global.cel_switched.emit())
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_undo_method(Global.canvas.draw_layers)
	project.undo_redo.add_undo_method(func(): Global.cel_switched.emit())
	project.undo_redo.commit_action()


func _on_audio_file_button_pressed() -> void:
	audio_file_dialog.popup_centered()


func _on_play_at_frame_slider_value_changed(value: float) -> void:
	if layer_indices.size() == 0:
		return
	for layer_index in layer_indices:
		var layer := Global.current_project.layers[layer_index]
		if layer is AudioLayer:
			layer.playback_frame = value - 1


func _on_audio_file_dialog_file_selected(path: String) -> void:
	var audio_stream: AudioStream
	if path.to_lower().get_extension() == "mp3":
		var file := FileAccess.open(path, FileAccess.READ)
		audio_stream = AudioStreamMP3.new()
		audio_stream.data = file.get_buffer(file.get_length())
	elif path.to_lower().get_extension() == "wav":
		var file := FileAccess.open(path, FileAccess.READ)
		audio_stream = AudioStreamWAV.load_from_buffer(file.get_buffer(file.get_length()))
	for layer_index in layer_indices:
		var layer := Global.current_project.layers[layer_index]
		if layer is AudioLayer:
			layer.audio = audio_stream


func _on_place_only_mode_check_button_toggled(toggled_on: bool) -> void:
	if not toggled_on:
		return
	place_only_mode_check_button.set_pressed_no_signal(false)
	place_only_confirmation_dialog.popup_centered()


func _on_place_only_confirmation_dialog_confirmed() -> void:
	var project := Global.current_project
	project.undos += 1
	project.undo_redo.create_action("Set place-only mode")
	for layer_index in layer_indices:
		var layer := project.layers[layer_index]
		if layer is not LayerTileMap:
			continue
		project.undo_redo.add_do_property(layer, "place_only_mode", true)
		project.undo_redo.add_undo_property(layer, "place_only_mode", layer.place_only_mode)
		for frame in project.frames:
			for i in frame.cels.size():
				var cel := frame.cels[i]
				if cel is CelTileMap and i == layer_index:
					project.undo_redo.add_do_property(cel, "place_only_mode", true)
					project.undo_redo.add_undo_property(cel, "place_only_mode", cel.place_only_mode)
	place_only_mode_check_button.disabled = true
	get_tree().set_group(&"TilemapLayersPlaceOnly", "visible", true)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_do_method(func(): Global.cel_switched.emit())
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_undo_method(func(): Global.cel_switched.emit())
	project.undo_redo.commit_action()
	place_only_mode_check_button.set_pressed_no_signal(true)


func _on_tile_size_slider_value_changed(value: Vector2) -> void:
	var project := Global.current_project
	project.undos += 1
	project.undo_redo.create_action("Change tilemap settings")
	for layer_index in layer_indices:
		var layer := project.layers[layer_index]
		if layer is not LayerTileMap:
			continue
		project.undo_redo.add_do_property(layer, "tile_size", value)
		project.undo_redo.add_undo_property(layer, "tile_size", layer.tile_size)
		for frame in project.frames:
			for i in frame.cels.size():
				var cel := frame.cels[i]
				if cel is CelTileMap and i == layer_index:
					project.undo_redo.add_do_property(cel, "tile_size", value)
					project.undo_redo.add_undo_property(cel, "tile_size", cel.tile_size)

	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_do_method(func(): Global.canvas.queue_redraw())
	project.undo_redo.add_do_method(func(): Global.canvas.grid.queue_redraw())
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_undo_method(func(): Global.canvas.queue_redraw())
	project.undo_redo.add_undo_method(func(): Global.canvas.grid.queue_redraw())
	project.undo_redo.commit_action()


func _on_tile_shape_option_button_item_selected(index: TileSet.TileShape) -> void:
	var selected_id := tile_shape_option_button.get_item_id(index)
	var project := Global.current_project
	project.undos += 1
	project.undo_redo.create_action("Change tilemap settings")
	for layer_index in layer_indices:
		var layer := project.layers[layer_index]
		if layer is not LayerTileMap:
			continue
		project.undo_redo.add_do_property(layer, "tile_shape", selected_id)
		project.undo_redo.add_undo_property(layer, "tile_shape", layer.tile_shape)
		for frame in project.frames:
			for i in frame.cels.size():
				var cel := frame.cels[i]
				if cel is CelTileMap and i == layer_index:
					project.undo_redo.add_do_property(cel, "tile_shape", selected_id)
					project.undo_redo.add_undo_property(cel, "tile_shape", cel.tile_shape)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_do_method(func(): Global.canvas.queue_redraw())
	project.undo_redo.add_do_method(func(): Global.canvas.grid.queue_redraw())
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_undo_method(func(): Global.canvas.queue_redraw())
	project.undo_redo.add_undo_method(func(): Global.canvas.grid.queue_redraw())
	project.undo_redo.commit_action()


func _on_tile_layout_option_button_item_selected(index: TileSet.TileLayout) -> void:
	var project := Global.current_project
	project.undos += 1
	project.undo_redo.create_action("Change tilemap settings")
	for layer_index in layer_indices:
		var layer := project.layers[layer_index]
		if layer is not LayerTileMap:
			continue
		project.undo_redo.add_do_property(layer, "tile_layout", index)
		project.undo_redo.add_undo_property(layer, "tile_layout", layer.tile_layout)
		for frame in project.frames:
			for i in frame.cels.size():
				var cel := frame.cels[i]
				if cel is CelTileMap and i == layer_index:
					project.undo_redo.add_do_property(cel, "tile_layout", index)
					project.undo_redo.add_undo_property(cel, "tile_layout", cel.tile_layout)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_do_method(func(): Global.canvas.queue_redraw())
	project.undo_redo.add_do_method(func(): Global.canvas.grid.queue_redraw())
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_undo_method(func(): Global.canvas.queue_redraw())
	project.undo_redo.add_undo_method(func(): Global.canvas.grid.queue_redraw())
	project.undo_redo.commit_action()


func _on_tile_offset_axis_button_item_selected(index: TileSet.TileOffsetAxis) -> void:
	var selected_id := tile_offset_axis_button.get_item_id(index)
	var project := Global.current_project
	project.undos += 1
	project.undo_redo.create_action("Change tilemap settings")
	for layer_index in layer_indices:
		var layer := project.layers[layer_index]
		if layer is not LayerTileMap:
			continue
		project.undo_redo.add_do_property(layer, "tile_offset_axis", selected_id)
		project.undo_redo.add_undo_property(layer, "tile_offset_axis", layer.tile_offset_axis)
		for frame in project.frames:
			for i in frame.cels.size():
				var cel := frame.cels[i]
				if cel is CelTileMap and i == layer_index:
					project.undo_redo.add_do_property(cel, "tile_offset_axis", selected_id)
					project.undo_redo.add_undo_property(
						cel, "tile_offset_axis", cel.tile_offset_axis
					)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_do_method(func(): Global.canvas.queue_redraw())
	project.undo_redo.add_do_method(func(): Global.canvas.grid.queue_redraw())
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_undo_method(func(): Global.canvas.queue_redraw())
	project.undo_redo.add_undo_method(func(): Global.canvas.grid.queue_redraw())
	project.undo_redo.commit_action()
