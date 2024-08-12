extends SubViewportContainer

@export var camera_path: NodePath

var _mouse_inside = false

@onready var camera := get_node(camera_path) as CanvasCamera


func _ready() -> void:
	material = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA


func _input(event):
	if event is InputEventMouseMotion:
		if get_global_rect().has_point(event.position):
			if !_mouse_inside:
				_mouse_inside = true
				camera.set_process_input(true)
				Global.control.left_cursor.visible = Global.show_left_tool_icon
				Global.control.right_cursor.visible = Global.show_right_tool_icon
				if Global.cross_cursor:
					Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		else:
			if _mouse_inside:
				_mouse_inside = false
				camera.drag = false
				Global.control.left_cursor.visible = false
				Global.control.right_cursor.visible = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
