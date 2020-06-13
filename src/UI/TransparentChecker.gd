extends ColorRect


func _ready() -> void:
	rect_size = Global.current_project.size
	if get_parent().get_parent() == Global.main_viewport:
		Global.second_viewport.get_node("Viewport/TransparentChecker")._ready()
		Global.small_preview_viewport.get_node("Viewport/TransparentChecker")._ready()
	material.set_shader_param("size", Global.checker_size)
	material.set_shader_param("color1", Global.checker_color_1)
	material.set_shader_param("color2", Global.checker_color_2)
