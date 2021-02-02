extends ColorRect


func _ready() -> void:
	rect_size = Global.current_project.size
	if self == Global.transparent_checker:
		fit_rect(Global.current_project.get_tile_mode_rect())
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


func _on_TransparentChecker_resized() -> void:
	material.set_shader_param("rect_size", rect_size)


func fit_rect(rect : Rect2) -> void:
	rect_position = rect.position
	rect_size = rect.size


func transparency(value :float) -> void:
	# first make viewport transparent then background and then viewport
	if value == 1:
		get_parent().transparent_bg = false
		get_tree().get_root().set_transparent_background(false)
	else:
		OS.window_per_pixel_transparency_enabled = true
		get_parent().transparent_bg = true
		get_tree().get_root().set_transparent_background(true)

	# this controls opacity 0 for transparent, 1 or a greater value than 1 is opaque
	# i have set a minimum amount for the fade (We would'nt want the canvas to dissapear now would we?)
	material.set("shader_param/alpha",clamp(value,0.1,1))
