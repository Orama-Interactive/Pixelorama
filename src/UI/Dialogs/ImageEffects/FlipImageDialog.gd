extends ImageEffect

onready var flip_h: CheckBox = $VBoxContainer/OptionsContainer/FlipHorizontal
onready var flip_v: CheckBox = $VBoxContainer/OptionsContainer/FlipVertical


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	_flip_image(cel, selection_checkbox.pressed, project)


func _on_FlipHorizontal_toggled(_button_pressed: bool) -> void:
	update_preview()


func _on_FlipVertical_toggled(_button_pressed: bool) -> void:
	update_preview()


func _flip_image(cel: Image, affect_selection: bool, project: Project) -> void:
	if !(affect_selection and project.has_selection):
		if flip_h.pressed:
			cel.flip_x()
		if flip_v.pressed:
			cel.flip_y()
	else:
		# Create a temporary image that only has the selected pixels in it
		var selected := Image.new()
		var rectangle: Rect2 = Global.canvas.selection.big_bounding_rectangle
		if project != Global.current_project:
			rectangle = project.selection_map.get_used_rect()
		selected = cel.get_rect(rectangle)
		selected.lock()
		cel.lock()
		for x in selected.get_width():
			for y in selected.get_height():
				var pos := Vector2(x, y)
				var cel_pos := pos + rectangle.position
				if project.can_pixel_get_drawn(cel_pos):
					cel.set_pixelv(cel_pos, Color(0, 0, 0, 0))
				else:
					selected.set_pixelv(pos, Color(0, 0, 0, 0))

		selected.unlock()
		cel.unlock()
		if flip_h.pressed:
			selected.flip_x()
		if flip_v.pressed:
			selected.flip_y()
		cel.blend_rect(selected, Rect2(Vector2.ZERO, selected.get_size()), rectangle.position)


func _commit_undo(action: String, undo_data: Dictionary, project: Project) -> void:
	_flip_selection(project)

	var redo_data := _get_undo_data(project)
	project.undos += 1
	project.undo_redo.create_action(action)
	project.undo_redo.add_do_property(project, "selection_map", redo_data["selection_map"])
	project.undo_redo.add_do_property(project, "selection_offset", redo_data["outline_offset"])
	project.undo_redo.add_undo_property(project, "selection_map", undo_data["selection_map"])
	project.undo_redo.add_undo_property(project, "selection_offset", undo_data["outline_offset"])

	for image in redo_data:
		if not image is Image:
			continue
		project.undo_redo.add_do_property(image, "data", redo_data[image])
		image.unlock()
	for image in undo_data:
		if not image is Image:
			continue
		project.undo_redo.add_undo_property(image, "data", undo_data[image])
	project.undo_redo.add_do_method(Global, "undo_or_redo", false, -1, -1, project)
	project.undo_redo.add_do_method(project, "selection_map_changed")
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true, -1, -1, project)
	project.undo_redo.add_undo_method(project, "selection_map_changed")
	project.undo_redo.commit_action()


func _get_undo_data(project: Project) -> Dictionary:
	var bitmap_image := SelectionMap.new()
	bitmap_image.copy_from(project.selection_map)
	var data := {}
	data["selection_map"] = bitmap_image
	data["outline_offset"] = project.selection_offset

	var images := _get_selected_draw_images(project)
	for image in images:
		image.unlock()
		data[image] = image.data

	return data


func _flip_selection(project: Project = Global.current_project) -> void:
	if !(selection_checkbox.pressed and project.has_selection):
		return

	var bitmap_image := SelectionMap.new()
	bitmap_image.copy_from(project.selection_map)
	var selection_rect := bitmap_image.get_used_rect()
	var smaller_bitmap_image := bitmap_image.get_rect(selection_rect)

	if flip_h.pressed:
		smaller_bitmap_image.flip_x()
	if flip_v.pressed:
		smaller_bitmap_image.flip_y()

	bitmap_image.fill(Color(0, 0, 0, 0))
	bitmap_image.blend_rect(
		smaller_bitmap_image,
		Rect2(Vector2.ZERO, smaller_bitmap_image.get_size()),
		selection_rect.position
	)
	project.selection_map = bitmap_image
