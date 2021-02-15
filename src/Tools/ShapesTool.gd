extends "res://src/Tools/Draw.gd"

class ShapeToolOption:
	var name: String

	func _init(n: String) -> void:
		name = n


	func get_draw_points(start_pos : Vector2, end_pos : Vector2) -> PoolVector2Array:
		return PoolVector2Array()


class Rectangle extends ShapeToolOption:
	func _init().("Rectangle"):
		pass


	func get_draw_points(start_pos : Vector2, end_pos : Vector2) -> PoolVector2Array:
		var pool := PoolVector2Array()

		for x in range(start_pos.x, end_pos.x + 1):
			pool.append(Vector2(x,start_pos.y))
			pool.append(Vector2(x,end_pos.y))

		for y in range(start_pos.y, end_pos.y + 1):
			pool.append(Vector2(start_pos.x,y))
			pool.append(Vector2(end_pos.x,y))

		return pool


#	func create_indicator(start_pos : Vector2, end_pos : Vector2) -> BitMap:
#		var indicator_bitmap = BitMap.new()
#		var size = (end_pos - start_pos) + Vector2.ONE
#		indicator_bitmap.create(size)
#
#		for x in range(size.x):
#			indicator_bitmap.set_bit(Vector2(x,0), 1)
#			indicator_bitmap.set_bit(Vector2(x,size.y-1), 1)
#
#		for y in range(size.y):
#			indicator_bitmap.set_bit(Vector2(0,y), 1)
#			indicator_bitmap.set_bit(Vector2(size.x-1,y), 1)
#
#		return indicator_bitmap


#	func draw_shape(start_pos : Vector2, end_pos : Vector2, t) -> void:
#		for x in range(start_pos.x, end_pos.x + 1):
#			t.draw_tool(Vector2(x,start_pos.y))
#			t.draw_tool(Vector2(x,end_pos.y))
#
#		for y in range(start_pos.y, end_pos.y + 1):
#			t.draw_tool(Vector2(start_pos.x,y))
#			t.draw_tool(Vector2(end_pos.x,y))


class Elipse extends ShapeToolOption:
	func _init().("Elispe"):
		pass


#	func create_indicator(start_pos : Vector2, end_pos : Vector2) -> BitMap:
#		var indicator_bitmap = BitMap.new()
#		var size = end_pos - start_pos
#		indicator_bitmap.create(size + Vector2.ONE)
#
#		for point in get_draw_points(Vector2.ZERO, size):
#			indicator_bitmap.set_bit(point, 1)
#
#		return indicator_bitmap

# Algorithm based on http://members.chello.at/easyfilter/bresenham.html
	func get_draw_points(start_pos : Vector2, end_pos : Vector2) -> PoolVector2Array:
		var pool := PoolVector2Array()
		var x0 : int = start_pos.x
		var x1 : int = end_pos.x
		var y0 : int = start_pos.y
		var y1 : int = end_pos.y
		var a : int = abs(x0 - x1)
		var b : int = abs(y0 - y1)
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
			pool.append(Vector2(x1+1, y0+1))
			pool.append(Vector2(x0-1, y1))
			pool.append(Vector2(x1+1, y1-1))
			y0+=1
			y1-=1

		return pool



var _start := Vector2.ZERO
var _dest := Vector2.ZERO
var _shapes := [
	Rectangle.new(),
	Elipse.new(),
]
var _selected := 0
var _drawing := false


func _init() -> void:
	_drawer.color_op = Drawer.ColorOp.new()


func _ready():
	for shape in _shapes:
		$ShapesDropdown.add_item(shape.name)


func draw_start(position : Vector2) -> void:
	update_mask()
	prepare_undo()

	_start = position
	_dest = position
	_drawing = true


func draw_move(position : Vector2) -> void:
	_dest = position


func draw_end(position : Vector2) -> void:
	var result_rect = _get_result_rect(_start, position)

	for point in _shapes[_selected].get_draw_points(result_rect.position, result_rect.end):
		draw_tool(point)
#	_shapes[_selected].draw_shape(result_rect.position, result_rect.end, self)

	commit_undo("Draw Shape")

	_start = Vector2.ZERO
	_dest = Vector2.ZERO

	_drawing = false


func draw_indicator():
	.draw_indicator()

	if _drawing:
		var canvas = Global.canvas.indicators
		var rect = _get_result_rect(_start, _dest)
		var indicator = BitMap.new()
		indicator.create(rect.size + Vector2.ONE)
		for point in _shapes[_selected].get_draw_points(Vector2.ZERO, rect.size):
			indicator.set_bit(point, 1)

		var polylines = _create_polylines(indicator)

		canvas.draw_set_transform(rect.position, canvas.rotation, canvas.scale)
		for line in polylines:
			var pool := PoolVector2Array(line)
			canvas.draw_polyline(pool, Color.black)
		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func _get_result_rect(origin: Vector2, dest: Vector2) -> Rect2:
	var rect := Rect2(Vector2.ZERO, Vector2.ZERO)

	if Tools.shift:
		var square_size := min(abs(origin.x - dest.x), abs(origin.y - dest.y))
		rect.position.x = origin.x if origin.x < dest.x else origin.x - square_size
		rect.position.y = origin.y if origin.y < dest.y else origin.y - square_size
		rect.size = Vector2(square_size, square_size)
	else:
		rect.position = Vector2(min(origin.x, dest.x), min(origin.y, dest.y))
		rect.size = (origin - dest).abs()

	return rect


func _on_ShapesDropdown_item_selected(index: int) -> void:
	_selected = index
