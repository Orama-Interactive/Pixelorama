extends VFlowContainer

@onready var top_menu_container: Panel = $"../../.."


func _ready() -> void:
	if DisplayServer.is_touchscreen_available():
		show()


func _on_save_pressed() -> void:
	top_menu_container.file_menu_id_pressed(Global.FileMenu.SAVE)


func _on_undo_pressed() -> void:
	top_menu_container.edit_menu_id_pressed(Global.EditMenu.UNDO)


func _on_redo_pressed() -> void:
	top_menu_container.edit_menu_id_pressed(Global.EditMenu.REDO)


func _on_copy_pressed() -> void:
	top_menu_container.edit_menu_id_pressed(Global.EditMenu.COPY)


func _on_cut_pressed() -> void:
	top_menu_container.edit_menu_id_pressed(Global.EditMenu.CUT)


func _on_paste_pressed() -> void:
	top_menu_container.edit_menu_id_pressed(Global.EditMenu.PASTE)


func _on_delete_pressed() -> void:
	top_menu_container.edit_menu_id_pressed(Global.EditMenu.DELETE)


func _on_shift_toggled(toggled_on: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.pressed = toggled_on
	Input.parse_input_event(event)


func _on_ctrl_toggled(toggled_on: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_CTRL
	event.pressed = toggled_on
	Input.parse_input_event(event)


func _on_alt_toggled(toggled_on: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ALT
	event.pressed = toggled_on
	Input.parse_input_event(event)
