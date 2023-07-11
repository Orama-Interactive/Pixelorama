class_name SelectionMap
extends Image

var invert_shader: Shader = preload("res://src/Shaders/Invert.gdshader")


func is_pixel_selected(pixel: Vector2) -> bool:
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= get_width() or pixel.y >= get_height():
		return false
	var selected: bool = get_pixelv(pixel).a > 0
	return selected


func get_nearest_position(pixel: Vector2) -> Vector2:
	if Global.canvas.selection.flag_tilemode:
		# functions more or less the same way as the tilemode
		var size := Global.current_project.size
		var selection_rect := get_used_rect()
		var start_x = selection_rect.position.x - selection_rect.size.x
		var end_x = selection_rect.position.x + 2 * selection_rect.size.x
		var start_y = selection_rect.position.y - selection_rect.size.y
		var end_y = selection_rect.position.y + 2 * selection_rect.size.y
		for x in range(start_x, end_x, selection_rect.size.x):
			for y in range(start_y, end_y, selection_rect.size.y):
				var test_image := Image.create(size.x, size.y, false, Image.FORMAT_LA8)
				test_image.blit_rect(self, selection_rect, Vector2(x, y))
				if (
					pixel.x < 0
					or pixel.y < 0
					or pixel.x >= test_image.get_width()
					or pixel.y >= test_image.get_height()
				):
					continue
				var selected: bool = test_image.get_pixelv(pixel).a > 0
				if selected:
					var offset := Vector2i(x, y) - selection_rect.position
					return offset
		return Vector2.ZERO
	else:
		return Vector2.ZERO


func get_point_in_tile_mode(pixel: Vector2) -> Array:
	var result := []
	if Global.canvas.selection.flag_tilemode:
		var selection_rect = get_used_rect()
		var start_x = selection_rect.position.x - selection_rect.size.x
		var end_x = selection_rect.position.x + 2 * selection_rect.size.x
		var start_y = selection_rect.position.y - selection_rect.size.y
		var end_y = selection_rect.position.y + 2 * selection_rect.size.y
		for x in range(start_x, end_x, selection_rect.size.x):
			for y in range(start_y, end_y, selection_rect.size.y):
				result.append(Vector2(x, y) + pixel - selection_rect.position)
	else:
		result.append(pixel)
	return result


func get_canon_position(position) -> Vector2:
	if Global.canvas.selection.flag_tilemode:
		return position - get_nearest_position(position)
	else:
		return position


func select_pixel(pixel: Vector2, select := true) -> void:
	if select:
		set_pixelv(pixel, Color(1, 1, 1, 1))
	else:
		set_pixelv(pixel, Color(0))


func select_all() -> void:
	fill(Color(1, 1, 1, 1))


func clear() -> void:
	fill(Color(0))


func invert() -> void:
	var params := {"red": true, "green": true, "blue": true, "alpha": true}
	var gen := ShaderImageEffect.new()
	gen.generate_image(self, invert_shader, params, get_size())
	self.convert(Image.FORMAT_LA8)


func move_bitmap_values(project: Project, move_offset := true) -> void:
	var size := project.size
	var selection_node = Global.canvas.selection
	var selection_position: Vector2 = selection_node.big_bounding_rectangle.position
	var selection_end: Vector2 = selection_node.big_bounding_rectangle.end

	var selection_rect := get_used_rect()
	var smaller_image := get_region(selection_rect)
	clear()
	var dst := selection_position
	var x_diff = selection_end.x - size.x
	var y_diff = selection_end.y - size.y
	var nw := maxi(size.x, size.x + x_diff)
	var nh := maxi(size.y, size.y + y_diff)

	if selection_position.x < 0:
		nw -= selection_position.x
		if move_offset:
			project.selection_offset.x = selection_position.x
		dst.x = 0
	else:
		if move_offset:
			project.selection_offset.x = 0
	if selection_position.y < 0:
		nh -= selection_position.y
		if move_offset:
			project.selection_offset.y = selection_position.y
		dst.y = 0
	else:
		if move_offset:
			project.selection_offset.y = 0

	if nw <= size.x:
		nw = size.x
	if nh <= size.y:
		nh = size.y

	crop(nw, nh)
	blit_rect(smaller_image, Rect2(Vector2.ZERO, Vector2(nw, nh)), dst)


func resize_bitmap_values(
	project: Project, new_size: Vector2, flip_hor: bool, flip_ver: bool
) -> void:
	var size := project.size
	var selection_node: Node2D = Global.canvas.selection
	var selection_position: Vector2 = selection_node.big_bounding_rectangle.position
	var dst := selection_position
	var new_bitmap_size := size
	new_bitmap_size.x = maxi(size.x, abs(selection_position.x) + new_size.x)
	new_bitmap_size.y = maxi(size.y, abs(selection_position.y) + new_size.y)
	var selection_rect := get_used_rect()
	var smaller_image := get_region(selection_rect)
	if selection_position.x <= 0:
		project.selection_offset.x = selection_position.x
		dst.x = 0
	else:
		project.selection_offset.x = 0
	if selection_position.y <= 0:
		project.selection_offset.y = selection_position.y
		dst.y = 0
	else:
		project.selection_offset.y = 0
	clear()
	smaller_image.resize(new_size.x, new_size.y, Image.INTERPOLATE_NEAREST)
	if flip_hor:
		smaller_image.flip_x()
	if flip_ver:
		smaller_image.flip_y()
	if new_bitmap_size != size:
		crop(new_bitmap_size.x, new_bitmap_size.y)
	blit_rect(smaller_image, Rect2(Vector2.ZERO, new_bitmap_size), dst)
