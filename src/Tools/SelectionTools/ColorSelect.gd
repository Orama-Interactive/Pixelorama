extends SelectionTool

var shader: Shader = preload("res://src/Shaders/ColorSelect.gdshader")
var _similarity := 100


func get_config() -> Dictionary:
	var config := super.get_config()
	config["similarity"] = _similarity
	return config


func set_config(config: Dictionary) -> void:
	_similarity = config.get("similarity", _similarity)


func update_config() -> void:
	$SimilaritySlider.value = _similarity


func _on_Similarity_value_changed(value: float) -> void:
	_similarity = value
	update_config()
	save_config()


func apply_selection(position: Vector2) -> void:
	super.apply_selection(position)
	var project: Project = Global.current_project
	if position.x < 0 or position.y < 0:
		return
	if position.x > project.size.x - 1 or position.y > project.size.y - 1:
		return

	var cel_image := Image.new()
	cel_image.copy_from(_get_draw_image())
	var color := cel_image.get_pixelv(position)
	var operation := 0
	if _subtract:
		operation = 1
	elif _intersect:
		operation = 2

	var params := {"color": color, "similarity_percent": _similarity, "operation": operation}
	if _add or _subtract or _intersect:
		var selection_tex := ImageTexture.create_from_image(project.selection_map)
		params["selection"] = selection_tex
	var gen := ShaderImageEffect.new()
	gen.generate_image(cel_image, shader, params, project.size)
	cel_image.convert(Image.FORMAT_LA8)

	var selection_map_copy := SelectionMap.new()
	selection_map_copy.copy_from(cel_image)
	project.selection_map = selection_map_copy
	Global.canvas.selection.big_bounding_rectangle = project.selection_map.get_used_rect()
	Global.canvas.selection.commit_undo("Select", undo_data)
