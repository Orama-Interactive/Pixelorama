extends ColorRect


func _ready() -> void:
	rect_size = Global.current_project.size
	if get_parent().get_parent() == Global.main_viewport:
		Global.second_viewport.get_node("Viewport/TransparentChecker")._ready()
		Global.small_preview_viewport.get_node("Viewport/TransparentChecker")._ready()
	material.set_shader_param("size", Global.checker_size)
	material.set_shader_param("color1", Global.checker_color_1)
	material.set_shader_param("color2", Global.checker_color_2)
	material.set_shader_param("follow_movement", Global.checker_follow_movement)
	material.set_shader_param("follow_scale", Global.checker_follow_scale)


func update_offset(offset : Vector2, scale : Vector2) -> void:
	material.set_shader_param("offset", offset)
	material.set_shader_param("scale", scale)


func _on_TransparentChecker_resized():
	material.set_shader_param("rect_size", rect_size)
