extends "res://src/Tools/BaseShapeDrawer.gd"

var _radius := 0


func _get_shape_points_filled(pos: Vector2i, shape_size: Vector2i) -> Array[Vector2i]:
	return DrawingAlgos.get_rounded_rect_points_filled(pos, shape_size, _radius)


func _get_shape_points(pos: Vector2i, shape_size: Vector2i) -> Array[Vector2i]:
	return DrawingAlgos.get_rounded_rect_points(pos, shape_size, _radius, 1)


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
