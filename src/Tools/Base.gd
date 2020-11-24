extends VBoxContainer


var kname : String
var tool_slot : Tools.Slot = null
var cursor_text := ""

var _cursor := Vector2.INF


func _ready():
	kname = name.replace(" ", "_").to_lower()
	$Label.text = tool_slot.name

	yield(get_tree(), "idle_frame")
	load_config()
	$PixelPerfect.pressed = tool_slot.pixel_perfect
	$Mirror/Horizontal.pressed = tool_slot.horizontal_mirror
	$Mirror/Vertical.pressed = tool_slot.vertical_mirror


func _on_PixelPerfect_toggled(button_pressed : bool):
	tool_slot.pixel_perfect = button_pressed
	tool_slot.save_config()


func _on_Horizontal_toggled(button_pressed : bool):
	tool_slot.horizontal_mirror = button_pressed
	tool_slot.save_config()
	Global.show_y_symmetry_axis = button_pressed
	# If the button is not pressed but another button is, keep the symmetry guide visible
	if !button_pressed and (Tools._slots[BUTTON_LEFT].horizontal_mirror or Tools._slots[BUTTON_RIGHT].horizontal_mirror):
		Global.show_y_symmetry_axis = true
	Global.current_project.y_symmetry_axis.visible = Global.show_y_symmetry_axis and Global.show_guides


func _on_Vertical_toggled(button_pressed : bool):
	tool_slot.vertical_mirror = button_pressed
	tool_slot.save_config()
	Global.show_x_symmetry_axis = button_pressed
	# If the button is not pressed but another button is, keep the symmetry guide visible
	if !button_pressed and (Tools._slots[BUTTON_LEFT].vertical_mirror or Tools._slots[BUTTON_RIGHT].vertical_mirror):
		Global.show_x_symmetry_axis = true
	Global.current_project.x_symmetry_axis.visible = Global.show_x_symmetry_axis and Global.show_guides


func save_config() -> void:
	var config := get_config()
	Global.config_cache.set_value(tool_slot.kname, kname, config)


func load_config() -> void:
	var value = Global.config_cache.get_value(tool_slot.kname, kname, {})
	set_config(value)
	update_config()


func get_config() -> Dictionary:
	return {}


func set_config(_config : Dictionary) -> void:
	pass


func update_config() -> void:
	pass


func cursor_move(position : Vector2) -> void:
	_cursor = position


func draw_indicator() -> void:
	var rect := Rect2(_cursor, Vector2.ONE)
	Global.canvas.indicators.draw_rect(rect, Color.blue, false)


func _get_draw_rect() -> Rect2:
	var selected_pixels = Global.current_project.selected_pixels
	return Rect2(selected_pixels[0].x, selected_pixels[0].y, selected_pixels[-1].x - selected_pixels[0].x + 1, selected_pixels[-1].y - selected_pixels[0].y + 1)


func _get_tile_mode_rect() -> Rect2:
	match Global.current_project.tile_mode:
		Global.Tile_Mode.XAXIS:
			return Rect2(Vector2(-Global.current_project.size.x,0), Vector2(Global.current_project.size.x * 3,Global.current_project.size.y))
		Global.Tile_Mode.YAXIS:
			return Rect2(Vector2(0,-Global.current_project.size.y), Vector2(Global.current_project.size.x,Global.current_project.size.y * 3))
		Global.Tile_Mode.BOTH:
			return Rect2(-Global.current_project.size, Global.current_project.size * 3)
	return Rect2(Vector2(0,0),Global.current_project.size)



func _get_draw_image() -> Image:
	var project : Project = Global.current_project
	return project.frames[project.current_frame].cels[project.current_layer].image


func _flip_rect(rect : Rect2, size : Vector2, horizontal : bool, vertical : bool) -> Rect2:
	var result := rect
	if horizontal:
		result.position.x = size.x - rect.end.x
		result.end.x = size.x - rect.position.x
	if vertical:
		result.position.y = size.y - rect.end.y
		result.end.y = size.y - rect.position.y
	return result.abs()


func _create_polylines(bitmap : BitMap) -> Array:
	var lines := []
	var size := bitmap.get_size()
	for y in size.y:
		for x in size.x:
			var p := Vector2(x, y)
			if not bitmap.get_bit(p):
				continue
			if x <= 0 or not bitmap.get_bit(p - Vector2(1, 0)):
				_add_polylines_segment(lines, p, p + Vector2(0, 1))
			if y <= 0 or not bitmap.get_bit(p - Vector2(0, 1)):
				_add_polylines_segment(lines, p, p + Vector2(1, 0))
			if x + 1 >= size.x or not bitmap.get_bit(p + Vector2(1, 0)):
				_add_polylines_segment(lines, p + Vector2(1, 0), p + Vector2(1, 1))
			if y + 1 >= size.y or not bitmap.get_bit(p + Vector2(0, 1)):
				_add_polylines_segment(lines, p + Vector2(0, 1), p + Vector2(1, 1))
	return lines


func _add_polylines_segment(lines : Array, start : Vector2, end : Vector2) -> void:
	for line in lines:
		if line[0] == start:
			line.insert(0, end)
			return
		if line[0] == end:
			line.insert(0, start)
			return
		if line[line.size() - 1] == start:
			line.append(end)
			return
		if line[line.size() - 1] == end:
			line.append(start)
			return
	lines.append([start, end])
