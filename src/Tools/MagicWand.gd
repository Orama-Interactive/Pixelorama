extends BaseTool


var undo_data : Dictionary


func draw_start(_position : Vector2) -> void:
	Global.canvas.selection.move_content_confirm()
	undo_data = Global.canvas.selection._get_undo_data(false)


func draw_move(_position : Vector2) -> void:
	pass


func draw_end(position : Vector2) -> void:
	var project : Project = Global.current_project
	if position.x < 0 or position.y < 0:
		return
	if position.x > project.size.x - 1 or position.y > project.size.y - 1:
		return

	var subtract_from_selection : bool = Tools.control
	if !Tools.shift and !subtract_from_selection:
		Global.canvas.selection.clear_selection()

	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
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
			selection_bitmap_copy.set_bit(p, !subtract_from_selection)
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
