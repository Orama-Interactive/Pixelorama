extends ImageEffect

enum Animate { OFFSET_X, OFFSET_Y }

var shader := preload("res://src/Shaders/Effects/OffsetPixels.gdshader")
var wrap_around := false

@onready var offset_sliders := $VBoxContainer/OffsetOptions/OffsetSliders as ValueSliderV2


func _ready() -> void:
	super._ready()
	# Set in the order of the Animate enum
	animate_panel.add_float_property(
		"Offset X", $VBoxContainer/OffsetOptions/OffsetSliders.get_sliders()[0]
	)
	animate_panel.add_float_property(
		"Offset Y", $VBoxContainer/OffsetOptions/OffsetSliders.get_sliders()[1]
	)


func _about_to_popup() -> void:
	offset_sliders.min_value = -Global.current_project.size
	offset_sliders.max_value = Global.current_project.size
	super._about_to_popup()


func commit_action(cel: Image, project := Global.current_project) -> void:
	var offset_x := animate_panel.get_animated_value(commit_idx, Animate.OFFSET_X)
	var offset_y := animate_panel.get_animated_value(commit_idx, Animate.OFFSET_Y)
	var offset := Vector2(offset_x, offset_y)
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project.size)
		selection_tex = ImageTexture.create_from_image(selection)

	var params := {"offset": offset, "wrap_around": wrap_around, "selection": selection_tex}
	if !has_been_confirmed:
		recalculate_preview(params)
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)


func _on_OffsetSliders_value_changed(_value: Vector2) -> void:
	update_preview()  # (from here, commit_action will be called, and then recalculate_preview)


func _on_WrapCheckBox_toggled(button_pressed: bool) -> void:
	wrap_around = button_pressed
	update_preview()  # (from here, commit_action will be called, and then recalculate_preview)


func recalculate_preview(params: Dictionary) -> void:
	var frame := Global.current_project.frames[_preview_idx]
	commit_idx = _preview_idx
	match affect:
		SELECTED_CELS:
			selected_cels.fill(Color(0, 0, 0, 0))
			blend_layers(selected_cels, frame, params, true)
			preview_image.copy_from(selected_cels)
		_:
			current_frame.fill(Color(0, 0, 0, 0))
			blend_layers(current_frame, frame, params)
			preview_image.copy_from(current_frame)


## Altered version of blend_layers() located in DrawingAlgos.gd
## This function is REQUIRED in order for offset effect to work correctly with clipping masks
func blend_layers(
	image: Image,
	frame: Frame,
	effect_params := {},
	only_selected_cels := false,
	only_selected_layers := false,
) -> void:
	var project := Global.current_project
	var frame_index := project.frames.find(frame)
	var previous_ordered_layers: Array[int] = project.ordered_layers
	project.order_layers(frame_index)
	var textures: Array[Image] = []
	var gen := ShaderImageEffect.new()
	# Nx4 texture, where N is the number of layers and the first row are the blend modes,
	# the second are the opacities, the third are the origins and the fourth are the
	# clipping mask booleans.
	var metadata_image := Image.create(project.layers.size(), 4, false, Image.FORMAT_R8)
	for i in project.layers.size():
		var ordered_index := project.ordered_layers[i]
		var layer := project.layers[ordered_index]
		var include := true if layer.is_visible_in_hierarchy() else false
		if only_selected_cels and include:
			var test_array := [frame_index, i]
			if not test_array in project.selected_cels:
				include = false
		if only_selected_layers and include:
			var layer_is_selected := false
			for selected_cel in project.selected_cels:
				if i == selected_cel[1]:
					layer_is_selected = true
					break
			if not layer_is_selected:
				include = false
		var cel := frame.cels[ordered_index]
		var cel_image: Image
		if layer.is_blender():
			cel_image = (layer as GroupLayer).blend_children(frame)
		else:
			cel_image = layer.display_effects(cel)
		if layer.is_blended_by_ancestor() and not only_selected_cels and not only_selected_layers:
			include = false
		if include:  # Apply offset effect to it
			gen.generate_image(cel_image, shader, effect_params, project.size)
		textures.append(cel_image)
		DrawingAlgos.set_layer_metadata_image(layer, cel, metadata_image, ordered_index, include)
	var texture_array := Texture2DArray.new()
	texture_array.create_from_images(textures)
	var params := {
		"layers": texture_array,
		"metadata": ImageTexture.create_from_image(metadata_image),
	}
	var blended := Image.create(project.size.x, project.size.y, false, image.get_format())
	var blend_layers_shader = DrawingAlgos.blend_layers_shader
	gen.generate_image(blended, blend_layers_shader, params, project.size)
	image.blend_rect(blended, Rect2i(Vector2i.ZERO, project.size), Vector2i.ZERO)
	# Re-order the layers again to ensure correct canvas drawing
	project.ordered_layers = previous_ordered_layers
