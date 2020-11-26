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
	_init_position(Global.current_project.tile_mode)


func update_offset(offset : Vector2, scale : Vector2) -> void:
	material.set_shader_param("offset", offset)
	material.set_shader_param("scale", scale)


func _on_TransparentChecker_resized() -> void:
	material.set_shader_param("rect_size", rect_size)


func _init_position(id : int) -> void:
	match id:
		0:
			Global.current_project.tile_mode = Global.Tile_Mode.NONE
			Global.transparent_checker.set_size(Global.current_project.size)
			Global.transparent_checker.set_position(Vector2.ZERO)
		1:
			Global.current_project.tile_mode = Global.Tile_Mode.BOTH
			Global.transparent_checker.set_size(Global.current_project.size*3)
			Global.transparent_checker.set_position(-Global.current_project.size)
		2:
			Global.current_project.tile_mode = Global.Tile_Mode.XAXIS
			Global.transparent_checker.set_size(Vector2(Global.current_project.size.x*3, Global.current_project.size.y*1))
			Global.transparent_checker.set_position(Vector2(-Global.current_project.size.x, 0))
		3:
			Global.current_project.tile_mode = Global.Tile_Mode.YAXIS
			Global.transparent_checker.set_size(Vector2(Global.current_project.size.x*1, Global.current_project.size.y*3))
			Global.transparent_checker.set_position(Vector2(0, -Global.current_project.size.y))
