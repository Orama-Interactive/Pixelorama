extends SelectionTool


func apply_selection(position: Vector2) -> void:
	var project: Project = Global.current_project
	if position.x < 0 or position.y < 0:
		return
	if position.x > project.size.x - 1 or position.y > project.size.y - 1:
		return

	if !_add and !_subtract and !_intersect:
		Global.canvas.selection.clear_selection()

	var selection_map_copy := SelectionMap.new()
	selection_map_copy.copy_from(project.selection_map)
	if _intersect:
		selection_map_copy.clear()

	var cel_image := Image.new()
	cel_image.copy_from(_get_draw_image())
	cel_image.lock()
	var color := cel_image.get_pixelv(position)
	for x in cel_image.get_width():
		for y in cel_image.get_height():
			var pos := Vector2(x, y)
			if color.is_equal_approx(cel_image.get_pixelv(pos)):
				if _intersect:
					selection_map_copy.select_pixel(pos, selection_map_copy.is_pixel_selected(pos))
				else:
					selection_map_copy.select_pixel(pos, !_subtract)

	cel_image.unlock()
	project.selection_map = selection_map_copy
	Global.canvas.selection.big_bounding_rectangle = project.selection_map.get_used_rect()
	Global.canvas.selection.commit_undo("Select", undo_data)
