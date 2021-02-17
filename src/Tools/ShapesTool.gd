extends "res://src/Tools/Draw.gd"

class ShapeToolOption:
	var name: String

	func _init(n: String) -> void:
		name = n


	func get_draw_points_filled(_size: Vector2) -> PoolVector2Array:
		return PoolVector2Array()


	func get_draw_points(_size: Vector2) -> PoolVector2Array:
		return PoolVector2Array()


class Rectangle extends ShapeToolOption:
	func _init().(tr("Rectangle")):
		pass


	func get_draw_points_filled(_size: Vector2) -> PoolVector2Array:
		var pool := PoolVector2Array()

		for y in range(0, _size.y):
			for x in range(0, _size.x):
				pool.append(Vector2(x, y))

		return pool


	func get_draw_points(_size: Vector2) -> PoolVector2Array:
		var pool := PoolVector2Array()

		for x in range(0, _size.x):
			pool.append(Vector2(x, 0))
			pool.append(Vector2(x, _size.y - 1))

		for y in range(1, _size.y - 1):
			pool.append(Vector2(0, y))
			pool.append(Vector2(_size.x - 1, y))

		return pool


class Ellipse extends ShapeToolOption:
	func _init().(tr("Ellipse")):
		pass

# Probably a terrible way to do this, but I couldn't get any other algorithm to work correctly or that is consistent to the ellipse's get_draw_points
	func get_draw_points_filled(_size: Vector2) -> PoolVector2Array:
		var border = get_draw_points(_size)
		var pool := PoolVector2Array(border)
		var bitmap = BitMap.new()
		bitmap.create(_size)

		for point in border:
			bitmap.set_bit(point, 1)

		for x in range(1, ceil(_size.x / 2)):
			var fill := false
			var prev_was_true := false
			for y in range(0, ceil(_size.y / 2)):
				var top_l_p = Vector2(x, y)
				var bottom_l_p = Vector2(x, _size.y - y - 1)
				var top_r_p = Vector2(_size.x - x - 1, y)
				var bottom_r_p = Vector2(_size.x - x - 1, _size.y - y - 1)
				var bit = bitmap.get_bit(top_l_p)

				if bit and not prev_was_true and not fill:
					prev_was_true = true
				elif not bit and prev_was_true:
					pool.append(top_l_p)
					pool.append(bottom_l_p)
					pool.append(top_r_p)
					pool.append(bottom_r_p)
					prev_was_true = false
					fill = true
				elif fill and not bit:
					pool.append(top_l_p)
					pool.append(bottom_l_p)
					pool.append(top_r_p)
					pool.append(bottom_r_p)
				elif fill and bit:
					break

		return pool


# Algorithm based on http://members.chello.at/easyfilter/bresenham.html
	func get_draw_points(_size: Vector2) -> PoolVector2Array:
		var pool := PoolVector2Array()
		var x0 : int = 0
		var x1 : int = _size.x - 1
		var y0 : int = 0
		var y1 : int = _size.y - 1
		var a : int = x1
		var b : int = y1
		var b1 : int = b & 1
		var dx : int = 4*(1-a)*b*b
		var dy : int = 4*(b1+1)*a*a
		var err : int = dx+dy+b1*a*a
		var e2 : int = 0

		if x0 > x1:
			x0 = x1
			x1 += a

		if y0 > y1:
			y0 = y1

# warning-ignore:integer_division
		y0 += (b+1) / 2
		y1 = y0-b1
		a *= 8*a
		b1 = 8*b*b

		while x0 <= x1:
			pool.append(Vector2(x1, y0))
			pool.append(Vector2(x0, y0))
			pool.append(Vector2(x0, y1))
			pool.append(Vector2(x1, y1))
			e2 = 2*err;

			if e2 <= dy:
				y0 += 1
				y1 -= 1
				dy += a
				err += dy

			if e2 >= dx || 2*err > dy:
				x0+=1
				x1-=1
				dx += b1
				err += dx

		while y0-y1 < b:
			pool.append(Vector2(x0-1, y0))
			pool.append(Vector2(x1+1, y0))
			pool.append(Vector2(x0-1, y1))
			pool.append(Vector2(x1+1, y1))
			y0+=1
			y1-=1


		return pool


var _start := Vector2.ZERO
var _dest := Vector2.ZERO
var _shapes := [
	Rectangle.new(),
	Ellipse.new(),
]
var _curr_shape: ShapeToolOption = _shapes[0]
var _curr_shape_i := 0 setget _set_curr_shape_i
var _fill := 0
var _drawing := false


func _init() -> void:
	_drawer.color_op = Drawer.ColorOp.new()


func _ready() -> void:
	for shape in _shapes:
		$ShapesDropdown.add_item(shape.name)


func _on_ShapesDropdown_item_selected(index: int) -> void:
	_set_curr_shape_i(index)
	update_config()
	save_config()


func _on_FillCheckbox_toggled(button_pressed: bool) -> void:
	_fill = button_pressed
	update_config()
	save_config()


func get_config() -> Dictionary:
	var config := .get_config()
	config["fill"] = _fill
	config["curr_shape"] = _curr_shape_i
	return config


func set_config(config: Dictionary) -> void:
	.set_config(config)
	_fill = config.get("fill", _fill)
	_set_curr_shape_i(config.get("curr_shape", _curr_shape_i))


func update_config() -> void:
	.update_config()
	$FillCheckbox.pressed = _fill
	$ShapesDropdown.select(_curr_shape_i)


func draw_start(position : Vector2) -> void:
	update_mask()
	prepare_undo()

	_start = position
	_dest = position
	_drawing = true


func draw_move(position : Vector2) -> void:
	_dest = position


func draw_end(position : Vector2) -> void:
	var rect = _get_result_rect(_start, position)

	var points = _curr_shape.get_draw_points_filled(rect.size) if _fill else _curr_shape.get_draw_points(rect.size)
	for point in points:
		# Reset drawer every time because pixel perfect sometimes brake the tool
		_drawer.reset()
		draw_tool(rect.position + point)

	commit_undo("Draw Shape")
	_start = Vector2.ZERO
	_dest = Vector2.ZERO

	_drawing = false


func draw_preview() -> void:
	if _drawing:
		var canvas = Global.canvas.previews
		var rect = _get_result_rect(_start, _dest)
		var indicator = BitMap.new()
		var points = _curr_shape.get_draw_points_filled(rect.size) if _fill else _curr_shape.get_draw_points(rect.size)
		indicator.create(rect.size)
		for point in points:
			indicator.set_bit(point, 1)

		var polylines = _create_polylines(indicator)

		canvas.draw_set_transform(rect.position, canvas.rotation, canvas.scale)
		for line in polylines:
			var pool := PoolVector2Array(line)
			canvas.draw_polyline(pool, tool_slot.color)
		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func _get_result_rect(origin: Vector2, dest: Vector2) -> Rect2:
	var rect := Rect2(Vector2.ZERO, Vector2.ZERO)

	if Tools.alt:
		var new_size = (dest - origin).floor()
		if Tools.shift:
			var _square_size := max(abs(new_size.x), abs(new_size.y))
			new_size = Vector2(_square_size, _square_size)

		origin -= new_size
		dest = origin + 2 * new_size

	if Tools.shift and not Tools.alt:
		var square_size := min(abs(origin.x - dest.x), abs(origin.y - dest.y))
		rect.position.x = origin.x if origin.x < dest.x else origin.x - square_size
		rect.position.y = origin.y if origin.y < dest.y else origin.y - square_size
		rect.size = Vector2(square_size, square_size)
	else:
		rect.position = Vector2(min(origin.x, dest.x), min(origin.y, dest.y))
		rect.size = (origin - dest).abs()

	rect.size += Vector2.ONE
	return rect


func _set_curr_shape_i(i: int) -> void:
	_curr_shape_i = i
	_curr_shape = _shapes[i]
