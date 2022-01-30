extends Panel


onready var main_canvas_container = Global.main_canvas_container


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_transparent_shader()


func _on_Main_Canvas_item_rect_changed() -> void:
	update_transparent_shader()


func _on_Main_Canvas_visibility_changed() -> void:
	update_transparent_shader()


func update_transparent_shader():
	# works independently of the transparency frature
	material.set("shader_param/screen_resolution", get_viewport().size)
	material.set("shader_param/position", main_canvas_container.rect_global_position)
	material.set("shader_param/size", main_canvas_container.rect_size)

