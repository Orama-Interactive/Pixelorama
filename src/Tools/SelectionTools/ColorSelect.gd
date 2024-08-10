extends BaseSelectionTool

var shader := preload("res://src/Shaders/ColorSelect.gdshader")
var _tolerance := 0.003


func get_config() -> Dictionary:
	var config := super.get_config()
	config["tolerance"] = _tolerance
	return config


func set_config(config: Dictionary) -> void:
	_tolerance = config.get("tolerance", _tolerance)


func update_config() -> void:
	$ToleranceSlider.value = _tolerance * 255.0


func _on_tolerance_slider_value_changed(value: float) -> void:
	_tolerance = value / 255.0
	update_config()
	save_config()


func apply_selection(pos: Vector2i) -> void:
	super.apply_selection(pos)
	var project := Global.current_project
	if pos.x < 0 or pos.y < 0:
		return
	if pos.x > project.size.x - 1 or pos.y > project.size.y - 1:
		return

	var cel_image := Image.new()
	cel_image.copy_from(_get_draw_image())
	var color := cel_image.get_pixelv(pos)
	var operation := 0
	if _subtract:
		operation = 1
	elif _intersect:
		operation = 2

	var params := {"color": color, "tolerance": _tolerance, "operation": operation}
	if _add or _subtract or _intersect:
		var selection_tex := ImageTexture.create_from_image(project.selection_map)
		params["selection"] = selection_tex
	var gen := ShaderImageEffect.new()
	gen.generate_image(cel_image, shader, params, project.size)
	cel_image.convert(Image.FORMAT_LA8)

	project.selection_map.copy_from(cel_image)
	Global.canvas.selection.big_bounding_rectangle = project.selection_map.get_used_rect()
	Global.canvas.selection.commit_undo("Select", undo_data)
