extends SelectionTool


func apply_selection(position : Vector2) -> void:
	var project : Project = Global.current_project
	if position.x < 0 or position.y < 0:
		return
	if position.x > project.size.x - 1 or position.y > project.size.y - 1:
		return

	if !_add and !_subtract and !_intersect:
		Global.canvas.selection.clear_selection()

	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	if _intersect:
		var full_rect = Rect2(Vector2.ZERO, selection_bitmap_copy.get_size())
		selection_bitmap_copy.set_bit_rect(full_rect, false)

	var cel_image := Image.new()
	cel_image.copy_from(project.frames[project.current_frame].cels[project.current_layer].image)
	cel_image.lock()
	var color := cel_image.get_pixelv(position)
	for x in cel_image.get_width():
		for y in cel_image.get_width():
			var pos := Vector2(x, y)
			if color.is_equal_approx(cel_image.get_pixelv(pos)):
				if _intersect:
					selection_bitmap_copy.set_bit(pos, project.selection_bitmap.get_bit(pos))
				else:
					selection_bitmap_copy.set_bit(pos, !_subtract)

	cel_image.unlock()
	project.selection_bitmap = selection_bitmap_copy
	Global.canvas.selection.big_bounding_rectangle = project.get_selection_rectangle(project.selection_bitmap)
	Global.canvas.selection.commit_undo("Rectangle Select", undo_data)
