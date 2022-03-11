extends Panel

onready var main_canvas_container = Global.main_canvas_container


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_transparent_shader()


func _on_main_canvas_item_rect_changed() -> void:
	update_transparent_shader()


func _on_main_canvas_visibility_changed() -> void:
	update_transparent_shader()


func update_transparent_shader() -> void:
	# Works independently of the transparency feature
	material.set("shader_param/screen_resolution", get_viewport().size)
	material.set("shader_param/position", main_canvas_container.rect_global_position)
	material.set("shader_param/size", main_canvas_container.rect_size - Vector2.ONE * 2)
