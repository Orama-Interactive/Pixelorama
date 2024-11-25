extends Panel

var shader_disabled := false
var transparency_material: ShaderMaterial

@onready var dockable_container: DockableContainer = $DockableContainer
@onready var main_canvas_container := find_child("Main Canvas") as Container
@onready var tiles: TileSetPanel = $DockableContainer/Tiles


func _ready() -> void:
	Global.cel_switched.connect(_on_cel_switched)
	transparency_material = material
	main_canvas_container.property_list_changed.connect(_re_configure_shader)
	update_transparent_shader()
	dockable_container.set_control_hidden.call_deferred(tiles, true)


func _on_cel_switched() -> void:
	var cel := Global.current_project.get_current_cel()
	dockable_container.set_control_hidden(tiles, cel is not CelTileMap)


func _re_configure_shader() -> void:
	await get_tree().process_frame
	if get_window() != main_canvas_container.get_window():
		material = null
		shader_disabled = true
	else:
		if shader_disabled:
			material = transparency_material
			shader_disabled = false


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
	transparency_material.set_shader_parameter(
		"position", main_canvas_container.global_position * Global.shrink
	)
	transparency_material.set_shader_parameter("size", canvas_size)
