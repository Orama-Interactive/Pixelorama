class_name SelectionMap
extends Image

const INVERT_SHADER := preload("res://src/Shaders/Effects/Invert.gdshader")
const OUTLINE_INLINE_SHADER := preload("res://src/Shaders/Effects/OutlineInline.gdshader")


func is_pixel_selected(
	pixel: Vector2i, calculate_offset := true, project := Global.current_project
) -> bool:
	if calculate_offset:
		var selection_position := get_selection_rect(project).position
		if selection_position.x < 0:
			pixel.x -= selection_position.x
		if selection_position.y < 0:
			pixel.y -= selection_position.y
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= get_width() or pixel.y >= get_height():
		return false
	var selected: bool = get_pixelv(pixel).a > 0
	return selected


func get_nearest_position(pixel: Vector2i) -> Vector2i:
	if Global.canvas.selection.flag_tilemode:
		# functions more or less the same way as the tilemode
		var size := Global.current_project.size
		var selection_rect := get_used_rect()
		var start_x := selection_rect.position.x - selection_rect.size.x
		var end_x := selection_rect.position.x + 2 * selection_rect.size.x
		var start_y := selection_rect.position.y - selection_rect.size.y
		var end_y := selection_rect.position.y + 2 * selection_rect.size.y
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
		return Vector2i.ZERO
	else:
		return Vector2i.ZERO


func get_point_in_tile_mode(pixel: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if Global.canvas.selection.flag_tilemode:
		var selection_rect := get_used_rect()
		var start_x := selection_rect.position.x - selection_rect.size.x
		var end_x := selection_rect.position.x + 2 * selection_rect.size.x
		var start_y := selection_rect.position.y - selection_rect.size.y
		var end_y := selection_rect.position.y + 2 * selection_rect.size.y
		for x in range(start_x, end_x, selection_rect.size.x):
			for y in range(start_y, end_y, selection_rect.size.y):
				result.append(Vector2i(x, y) + pixel - selection_rect.position)
	else:
		result.append(pixel)
	return result


func get_canon_position(position: Vector2i) -> Vector2i:
	if Global.canvas.selection.flag_tilemode:
		return position - get_nearest_position(position)
	else:
		return position


func select_pixel(pixel: Vector2i, select := true) -> void:
	if select:
		set_pixelv(pixel, Color(1, 1, 1, 1))
	else:
		set_pixelv(pixel, Color(0))


func select_rect(rect: Rect2i, select := true) -> void:
	if select:
		fill_rect(rect, Color(1, 1, 1, 1))
	else:
		fill_rect(rect, Color(0))


func select_all() -> void:
	fill(Color(1, 1, 1, 1))


func clear() -> void:
	fill(Color(0))


func invert() -> void:
	var params := {"red": true, "green": true, "blue": true, "alpha": true}
	var gen := ShaderImageEffect.new()
	gen.generate_image(self, INVERT_SHADER, params, get_size())


func get_selection_rect(project: Project) -> Rect2i:
	var rect := get_used_rect()
	rect.position += project.selection_offset
	return rect


## Returns a copy of itself that is cropped to [param size].
## Used for when the selection map is bigger than the [Project] size.
func return_cropped_copy(project: Project, size: Vector2i) -> SelectionMap:
	var selection_map_copy := SelectionMap.new()
	selection_map_copy.copy_from(self)
	var diff := Vector2i.ZERO
	var selection_position := project.selection_offset
	if selection_position.x < 0:
		diff.x += selection_position.x
	if selection_position.y < 0:
		diff.y += selection_position.y
	if diff != Vector2i.ZERO:
		# If there are pixels out of bounds on the negative side (left & up),
		# move them before resizing
		selection_map_copy.fill(Color(0))
		selection_map_copy.blit_rect(self, Rect2i(Vector2i.ZERO, get_size()), diff)
	selection_map_copy.crop(size.x, size.y)
	return selection_map_copy


func blit_rect_custom(new_map: SelectionMap, rect: Rect2i, origin: Vector2i) -> void:
	clear()
	blit_rect(new_map, rect, origin)


func ensure_selection_fits(project: Project, rect: Rect2i) -> void:
	var current_size := Rect2i(Vector2i.ZERO, get_size())
	if current_size.encloses(rect):
		project.selection_offset = Vector2.ZERO
		return
	var new_size := current_size.merge(rect).size
	var offset := current_size.position.min(rect.position)
	crop(new_size.x, new_size.y)
	project.selection_offset = Vector2.ZERO.min(offset)


func move_bitmap_values(project: Project, move_offset := true) -> void:
	var size := project.size
	var selection_rect := get_selection_rect(project)
	var selection_position := selection_rect.position
	var selection_end := selection_rect.end
	var smaller_image := get_region(get_used_rect())
	clear()
	var dst := selection_position
	var x_diff := selection_end.x - size.x
	var y_diff := selection_end.y - size.y
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
	blit_rect(smaller_image, Rect2i(Vector2i.ZERO, Vector2i(nw, nh)), dst)


func expand(width: int, brush: int) -> void:
	var params := {
		"color": Color(1, 1, 1, 1),
		"width": width,
		"brush": brush,
	}
	var gen := ShaderImageEffect.new()
	gen.generate_image(self, OUTLINE_INLINE_SHADER, params, get_size())


func shrink(width: int, brush: int) -> void:
	var params := {
		"color": Color(0),
		"width": width,
		"brush": brush,
		"inside": true,
	}
	var gen := ShaderImageEffect.new()
	gen.generate_image(self, OUTLINE_INLINE_SHADER, params, get_size())


func border(width: int, brush: int) -> void:
	var params := {
		"color": Color(1, 1, 1, 1),
		"width": width,
		"brush": brush,
		"inside": true,
		"keep_border_only": true,
	}
	var gen := ShaderImageEffect.new()
	gen.generate_image(self, OUTLINE_INLINE_SHADER, params, get_size())
