extends Panel

@onready var main_canvas_container := find_child("Main Canvas") as Container


func _ready() -> void:
	update_transparent_shader()


func _on_main_canvas_item_rect_changed() -> void:
	update_transparent_shader()


func _on_main_canvas_visibility_changed() -> void:
	update_transparent_shader()


func update_transparent_shader() -> void:
	if not is_instance_valid(main_canvas_container):
		return
	# Works independently of the transparency feature
	var canvas_size: Vector2 = (main_canvas_container.size - Vector2.DOWN * 2) * Global.shrink
	material.set_shader_parameter("screen_resolution", get_viewport().size)
	material.set_shader_parameter("position", main_canvas_container.global_position * Global.shrink)
	material.set_shader_parameter("size", canvas_size)
