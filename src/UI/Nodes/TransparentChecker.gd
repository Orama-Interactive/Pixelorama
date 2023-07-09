extends ColorRect


func _ready() -> void:
	update_rect()


func update_rect() -> void:
	size = Global.current_project.size
	if self == Global.transparent_checker:
		fit_rect(Global.current_project.tiles.get_bounding_rect())
		Global.second_viewport.get_node("SubViewport/TransparentChecker").update_rect()
		Global.small_preview_viewport.get_node("SubViewport/TransparentChecker").update_rect()
	material.set_shader_parameter("size", Global.checker_size)
	material.set_shader_parameter("color1", Global.checker_color_1)
	material.set_shader_parameter("color2", Global.checker_color_2)
	material.set_shader_parameter("follow_movement", Global.checker_follow_movement)
	material.set_shader_parameter("follow_scale", Global.checker_follow_scale)


func update_offset(offset: Vector2, canvas_scale: Vector2) -> void:
	material.set_shader_parameter("offset", offset)
	material.set_shader_parameter("scale", canvas_scale)


func _on_TransparentChecker_resized() -> void:
	material.set_shader_parameter("size", size)


func fit_rect(rect: Rect2) -> void:
	position = rect.position
	size = rect.size


func update_transparency(value: float) -> void:
	# Change the transparency status of the parent viewport and the root viewport
	if value == 1.0:
		get_parent().transparent_bg = false
		get_tree().get_root().transparent_bg = false
	else:
		get_parent().transparent_bg = true
		get_tree().get_root().transparent_bg = true

	# Set a minimum amount for the fade so the canvas won't disappear
	material.set_shader_parameter("alpha", clampf(value, 0.1, 1))
