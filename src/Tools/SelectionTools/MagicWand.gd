extends "res://src/Tools/SelectionTools/SelectionTool.gd"


func draw_move(_position : Vector2) -> void:
	pass


func draw_end(position : Vector2) -> void:
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

	# Flood fill logic
	var processed := BitMap.new()
	processed.create(cel_image.get_size())
	var q = [position]
	for n in q:
		if processed.get_bit(n):
			continue
		var west : Vector2 = n
		var east : Vector2 = n
		while west.x >= 0 && cel_image.get_pixelv(west).is_equal_approx(color):
			west += Vector2.LEFT
		while east.x < project.size.x && cel_image.get_pixelv(east).is_equal_approx(color):
			east += Vector2.RIGHT
		for px in range(west.x + 1, east.x):
			var p := Vector2(px, n.y)
			if _intersect:
				selection_bitmap_copy.set_bit(p, project.selection_bitmap.get_bit(p))
			else:
				selection_bitmap_copy.set_bit(p, !_subtract)
			processed.set_bit(p, true)
			var north := p + Vector2.UP
			var south := p + Vector2.DOWN
			if north.y >= 0 && cel_image.get_pixelv(north).is_equal_approx(color):
				q.append(north)
			if south.y < project.size.y && cel_image.get_pixelv(south).is_equal_approx(color):
				q.append(south)

	cel_image.unlock()
	project.selection_bitmap = selection_bitmap_copy
	Global.canvas.selection.big_bounding_rectangle = project.get_selection_rectangle(project.selection_bitmap)
	Global.canvas.selection.commit_undo("Rectangle Select", undo_data)
