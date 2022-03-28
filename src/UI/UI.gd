extends Panel

onready var main_canvas_container: Container = find_node("Main Canvas")


func _ready() -> void:
	update_transparent_shader()


func _on_main_canvas_item_rect_changed() -> void:
	update_transparent_shader()


func _on_main_canvas_visibility_changed() -> void:
	update_transparent_shader()


func update_transparent_shader() -> void:
	# Works independently of the transparency feature
	var canvas_size: Vector2 = (main_canvas_container.rect_size - Vector2.DOWN * 2) * Global.shrink
	material.set("shader_param/screen_resolution", get_viewport().size)
	material.set(
		"shader_param/position", main_canvas_container.rect_global_position * Global.shrink
	)
	material.set("shader_param/size", canvas_size)
