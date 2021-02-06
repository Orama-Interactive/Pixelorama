extends BaseTool


var starting_pos : Vector2
var offset : Vector2


func draw_start(position : Vector2) -> void:
	starting_pos = position
	offset = position
	if Global.current_project.selected_pixels:
		Global.selection_rectangle.move_start(true)


func draw_move(position : Vector2) -> void:
	if Global.current_project.selected_pixels:
		Global.selection_rectangle.move_rect(position - offset)
	else:
		Global.canvas.move_preview_location = position - starting_pos
	offset = position


func draw_end(position : Vector2) -> void:
	if starting_pos != Vector2.INF:
		var pixel_diff : Vector2 = position - starting_pos
		if pixel_diff != Vector2.ZERO:
			var project : Project = Global.current_project
			var image : Image = _get_draw_image()
#			var pixels := []
#			if project.selected_pixels:
#				pixels = project.selected_pixels.duplicate()
#			else:
#				for x in Global.current_project.size.x:
#					for y in Global.current_project.size.y:
#						var pos := Vector2(x, y)
#						pixels.append([pos, image.get_pixelv(pos)])

#			print(pixels[3])
			if project.selected_pixels:
				Global.selection_rectangle.move_end()
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
