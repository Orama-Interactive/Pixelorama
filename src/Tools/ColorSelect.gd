extends BaseTool


var undo_data : Dictionary


func draw_start(_position : Vector2) -> void:
	Global.canvas.selection.move_content_confirm()
	undo_data = Global.canvas.selection._get_undo_data(false)


func draw_move(_position : Vector2) -> void:
	pass


func draw_end(position : Vector2) -> void:
	var subtract_from_selection : bool = Tools.control
	var project : Project = Global.current_project
	if position.x < 0 or position.y < 0:
		return
	if position.x > project.size.x - 1 or position.y > project.size.y - 1:
		return
	if !Tools.shift and !subtract_from_selection:
		Global.canvas.selection.clear_selection()
	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	var cel_image := Image.new()
	cel_image.copy_from(project.frames[project.current_frame].cels[project.current_layer].image)
	cel_image.lock()
	var color := cel_image.get_pixelv(position)
	for x in cel_image.get_width():
		for y in cel_image.get_width():
			var pos := Vector2(x, y)
			if color.is_equal_approx(cel_image.get_pixelv(pos)):
				selection_bitmap_copy.set_bit(pos, !subtract_from_selection)

	cel_image.unlock()
	project.selection_bitmap = selection_bitmap_copy
	Global.canvas.selection.big_bounding_rectangle = project.get_selection_rectangle(project.selection_bitmap)
	Global.canvas.selection.commit_undo("Rectangle Select", undo_data)
