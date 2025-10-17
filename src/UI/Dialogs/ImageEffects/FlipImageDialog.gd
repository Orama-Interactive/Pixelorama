extends ImageEffect

@onready var flip_h := $VBoxContainer/FlipOptions/FlipHorizontal as CheckBox
@onready var flip_v := $VBoxContainer/FlipOptions/FlipVertical as CheckBox


func commit_action(cel: Image, project := Global.current_project) -> void:
	_flip_image(cel, selection_checkbox.button_pressed, project)


func _on_FlipHorizontal_toggled(_button_pressed: bool) -> void:
	update_preview()


func _on_FlipVertical_toggled(_button_pressed: bool) -> void:
	update_preview()


func _flip_image(cel: Image, affect_selection: bool, project: Project) -> void:
	if !(affect_selection and project.has_selection):
		if flip_h.button_pressed:
			cel.flip_x()
		if flip_v.button_pressed:
			cel.flip_y()
	else:
		var cel_rect := Rect2i(Vector2i.ZERO, cel.get_size())
		# Create a temporary image that only has the selected pixels in it
		var selected := Image.create(cel.get_width(), cel.get_height(), false, cel.get_format())
		selected.blit_rect_mask(cel, project.selection_map, cel_rect, Vector2i.ZERO)
		var clear_image := Image.create(cel.get_width(), cel.get_height(), false, cel.get_format())
		clear_image.fill(Color(0, 0, 0, 0))
		cel.blit_rect_mask(clear_image, project.selection_map, cel_rect, Vector2i.ZERO)
		var rectangle := project.selection_map.get_selection_rect(project)
		if project != Global.current_project:
			rectangle = project.selection_map.get_used_rect()
		selected = selected.get_region(rectangle)

		if flip_h.button_pressed:
			selected.flip_x()
		if flip_v.button_pressed:
			selected.flip_y()
		cel.blend_rect(selected, Rect2i(Vector2i.ZERO, selected.get_size()), rectangle.position)
	if cel is ImageExtended:
		cel.convert_rgb_to_indexed()


func _commit_undo(action: String, undo_data: Dictionary, project: Project) -> void:
	_flip_selection(project)
	var tile_editing_mode := TileSetPanel.tile_editing_mode
	if tile_editing_mode == TileSetPanel.TileEditingMode.MANUAL:
		tile_editing_mode = TileSetPanel.TileEditingMode.AUTO
	project.update_tilemaps(undo_data, tile_editing_mode)
	var redo_data := _get_undo_data(project)
	project.undo_redo.create_action(action)
	project.deserialize_cel_undo_data(redo_data, undo_data)
	if redo_data.has("outline_offset"):
		project.undo_redo.add_do_property(project, "selection_offset", redo_data["outline_offset"])
		project.undo_redo.add_undo_property(
			project, "selection_offset", undo_data["outline_offset"]
		)
		project.undo_redo.add_do_method(project.selection_map_changed)
		project.undo_redo.add_undo_method(project.selection_map_changed)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false, -1, -1, project))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true, -1, -1, project))
	project.undo_redo.commit_action()


func _get_undo_data(project: Project) -> Dictionary:
	var affect_selection := selection_checkbox.button_pressed and project.has_selection
	var data := super._get_undo_data(project)
	if affect_selection:
		data[project.selection_map] = project.selection_map.data
		data["outline_offset"] = project.selection_offset
	return data


func _flip_selection(project := Global.current_project) -> void:
	if !(selection_checkbox.button_pressed and project.has_selection):
		return

	var selection_rect := project.selection_map.get_used_rect()
	var smaller_bitmap_image := project.selection_map.get_region(selection_rect)

	if flip_h.button_pressed:
		smaller_bitmap_image.flip_x()
	if flip_v.button_pressed:
		smaller_bitmap_image.flip_y()

	project.selection_map.fill(Color(0, 0, 0, 0))
	project.selection_map.blend_rect(
		smaller_bitmap_image,
		Rect2i(Vector2i.ZERO, smaller_bitmap_image.get_size()),
		selection_rect.position
	)
