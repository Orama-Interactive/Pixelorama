extends "res://src/Tools/Draw.gd"

var _last_position := Vector2.INF
var _changed := false
var _overwrite := false
var _draw_points = PoolVector2Array()

func _init() -> void:
	_drawer.color_op = preload("res://src/Tools/Pencil.gd").PencilOp.new()


func _on_Overwrite_toggled(button_pressed : bool):
	_overwrite = button_pressed
	update_config()
	save_config()


func get_config() -> Dictionary:
	var config := .get_config()
	config["overwrite"] = _overwrite
	return config


func set_config(config : Dictionary) -> void:
	.set_config(config)
	_overwrite = config.get("overwrite", _overwrite)


func update_config() -> void:
	.update_config()
	$Overwrite.pressed = _overwrite


func draw_start(position : Vector2) -> void:
	update_mask()
	_changed = false
	_drawer.color_op.changed = false
	_drawer.color_op.overwrite = _overwrite
	_draw_points = PoolVector2Array()

	prepare_undo()
	_drawer.reset()

	_draw_line = Tools.shift
	_draw_points.append(position)
	draw_tool(position)
	_last_position = position
	Global.canvas.sprite_changed_this_frame = true
	cursor_text = ""


func draw_move(position : Vector2) -> void:
	draw_fill_gap(_last_position, position)
	_last_position = position
	cursor_text = ""
	Global.canvas.sprite_changed_this_frame = true
	_draw_points.append(position)


func draw_end(_position : Vector2) -> void:
	_draw_points.append(_position)
	if _draw_points.size() > 3:
		var image = _get_draw_image()
		var v = Vector2()
		var image_size = image.get_size()
		for x in image_size.x:
			v.x = x
			for y in image_size.y:
				v.y = y
				if Geometry.is_point_in_polygon(v, _draw_points):
					draw_tool_pixel(v)
	if _changed or _drawer.color_op.changed:
		commit_undo("Draw")
	cursor_text = ""
	update_random_image()


func _draw_brush_image(image : Image, src_rect: Rect2, dst: Vector2) -> void:
	_changed = true
	if _overwrite:
		_get_draw_image().blit_rect(image, src_rect, dst)
	else:
		_get_draw_image().blend_rect(image, src_rect, dst)
