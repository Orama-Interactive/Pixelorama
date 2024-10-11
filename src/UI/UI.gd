extends Panel

@onready var main_canvas_container := find_child("Main Canvas") as Container

var shader_moved := false
var transparency_material: ShaderMaterial

func _ready() -> void:
	transparency_material = material
	main_canvas_container.property_list_changed.connect(_re_configure_shader)
	update_transparent_shader()


func _re_configure_shader():
	await get_tree().process_frame
	if get_window() != main_canvas_container.get_window():
		main_canvas_container.material = transparency_material
		material = null
		shader_moved = true
	else:
		if shader_moved:
			material = transparency_material
			shader_moved = false


func _on_main_canvas_item_rect_changed() -> void:
	update_transparent_shader()


func _on_main_canvas_visibility_changed() -> void:
	update_transparent_shader()


func update_transparent_shader() -> void:
	if not is_instance_valid(main_canvas_container):
		return
	# Works independently of the transparency feature
	var canvas_size: Vector2 = (main_canvas_container.size - Vector2.DOWN * 2) * Global.shrink
	transparency_material.set_shader_parameter("screen_resolution", get_viewport().size)
	transparency_material.set_shader_parameter("position", main_canvas_container.global_position * Global.shrink)
	transparency_material.set_shader_parameter("size", canvas_size)
