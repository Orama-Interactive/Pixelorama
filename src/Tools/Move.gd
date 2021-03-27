extends BaseTool


var starting_pos : Vector2
var offset : Vector2


func draw_start(position : Vector2) -> void:
	starting_pos = position
	offset = position
	if Global.current_project.has_selection():
		Global.canvas.selection.move_content_start()


func draw_move(position : Vector2) -> void:
	if Global.current_project.has_selection():
		Global.canvas.selection.move_content(position - offset)
		offset = position
	else:
		Global.canvas.move_preview_location = position - starting_pos
	offset = position


func draw_end(position : Vector2) -> void:
	if starting_pos != Vector2.INF:
		var pixel_diff : Vector2 = position - starting_pos
#		if pixel_diff != Vector2.ZERO:
		var project : Project = Global.current_project
		var image : Image = _get_draw_image()

		if project.has_selection():
			pass
#			Global.canvas.selection.move_content_end()
#			Global.canvas.selection.move_borders_end(position, starting_pos)
		else:
			Global.canvas.move_preview_location = Vector2.ZERO
			var image_copy := Image.new()
			image_copy.copy_from(image)
			Global.canvas.handle_undo("Draw")
			image.fill(Color(0, 0, 0, 0))
#			image.blit_rect(image_copy, Rect2(Vector2.ZERO, project.size), pixel_diff)
			image.blit_rect(image_copy, Rect2(Vector2.ZERO, project.size), pixel_diff)
#			for pixel in pixels:
##				image.set_pixelv(pixel[0] + pixel_diff, Color.red)
#				image.set_pixelv(pixel[0] + pixel_diff, pixel[1])
			Global.canvas.handle_redo("Draw")

			print(pixel_diff)
	starting_pos = Vector2.INF
