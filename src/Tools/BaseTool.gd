class_name BaseTool
extends VBoxContainer

var is_moving = false
var kname: String
var tool_slot = null  # Tools.Slot, can't have static typing due to cyclic errors
var cursor_text := ""
var _cursor := Vector2.INF

var _draw_cache: PoolVector2Array = []  # for storing already drawn pixels
var _for_frame := 0  # cache for which frame?

onready var color_rect: ColorRect = $ColorRect


func _ready() -> void:
	kname = name.replace(" ", "_").to_lower()
	if tool_slot.name == "Left tool":
		color_rect.color = Global.left_tool_color
	else:
		color_rect.color = Global.right_tool_color
	$Header/Label.text = Tools.tools[name].display_name

	load_config()


func save_config() -> void:
	var config := get_config()
	Global.config_cache.set_value(tool_slot.kname, kname, config)


func load_config() -> void:
	var value = Global.config_cache.get_value(tool_slot.kname, kname, {})
	set_config(value)
	update_config()


func get_config() -> Dictionary:
	return {}


func set_config(_config: Dictionary) -> void:
	pass


func update_config() -> void:
	pass


func draw_start(_position: Vector2) -> void:
	_draw_cache = []
	is_moving = true
	Global.current_project.can_undo = false


func draw_move(position: Vector2) -> void:
	# This can happen if the user switches between tools with a shortcut
	# while using another tool
	if !is_moving:
		draw_start(position)


func draw_end(_position: Vector2) -> void:
	is_moving = false
	_draw_cache = []
	Global.current_project.can_undo = true


func cursor_move(position: Vector2) -> void:
	_cursor = position


func draw_indicator(left: bool) -> void:
	var rect := Rect2(_cursor, Vector2.ONE)
	var color := Global.left_tool_color if left else Global.right_tool_color
	Global.canvas.indicators.draw_rect(rect, color, false)


func draw_preview() -> void:
	pass


func _get_draw_rect() -> Rect2:
	if Global.current_project.has_selection:
		return Global.current_project.selection_map.get_used_rect()
	else:
		return Rect2(Vector2.ZERO, Global.current_project.size)


func _get_draw_image() -> Image:
	var project: Project = Global.current_project
	return project.frames[project.current_frame].cels[project.current_layer].get_image()


func _get_selected_draw_images() -> Array:  # Array of Images
	var images := []
	var project: Project = Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if project.layers[cel_index[1]].can_layer_get_drawn():
			images.append(cel.image)
	return images


func _flip_rect(rect: Rect2, size: Vector2, horizontal: bool, vertical: bool) -> Rect2:
	var result := rect
	if horizontal:
		result.position.x = size.x - rect.end.x
		result.end.x = size.x - rect.position.x
	if vertical:
		result.position.y = size.y - rect.end.y
		result.end.y = size.y - rect.position.y
	return result.abs()


func _create_polylines(bitmap: BitMap) -> Array:
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


func _fill_bitmap_with_points(points: Array, size: Vector2) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create(size)

	for point in points:
		if point.x < 0 or point.y < 0 or point.x >= size.x or point.y >= size.y:
			continue
		bitmap.set_bit(point, 1)

	return bitmap


func _add_polylines_segment(lines: Array, start: Vector2, end: Vector2) -> void:
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


func _exit_tree() -> void:
	if is_moving:
		draw_end(Global.canvas.current_pixel.floor())
