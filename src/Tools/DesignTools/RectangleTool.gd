extends "res://src/Tools/BaseShapeDrawer.gd"

var _radius := 0


func _get_shape_points_filled(shape_size: Vector2i) -> Array[Vector2i]:
	if _radius <= 0:
		var array: Array[Vector2i] = []
		var t_of := _thickness - 1
		for y in range(shape_size.y + t_of):
			for x in range(shape_size.x + t_of):
				array.append(Vector2i(x, y))
		return array

	return DrawingAlgos.get_rounded_rect_points_filled(Vector2.ZERO, shape_size, _radius)


func _get_shape_points(shape_size: Vector2i) -> Array[Vector2i]:
	return DrawingAlgos.get_rounded_rect_points(Vector2i.ZERO, shape_size, _radius, _thickness)


func get_config() -> Dictionary:
	var config := super()
	config["radius"] = _radius
	return config


func set_config(config: Dictionary) -> void:
	super(config)
	_radius = config.get("radius", _radius)


func update_config() -> void:
	super()
	$RadiusValueSlider.value = _radius


func _on_radius_value_slider_value_changed(value: float) -> void:
	_radius = value
	update_indicator()
	update_config()
	save_config()
