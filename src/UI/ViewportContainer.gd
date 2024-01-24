extends SubViewportContainer

@export var camera_path: NodePath

@onready var camera := get_node(camera_path) as Camera2D


func _ready() -> void:
	material = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA


func _on_ViewportContainer_mouse_entered() -> void:
	camera.set_process_input(true)
	Global.control.left_cursor.visible = Global.show_left_tool_icon
	Global.control.right_cursor.visible = Global.show_right_tool_icon


func _on_ViewportContainer_mouse_exited() -> void:
	camera.set_process_input(false)
	Global.control.left_cursor.visible = false
	Global.control.right_cursor.visible = false
