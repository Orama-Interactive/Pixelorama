class_name LayerButton
extends Button


var i := 0
var visibility_button : BaseButton
var lock_button : BaseButton
var linked_button : BaseButton
var label : Label
var line_edit : LineEdit


func _ready() -> void:
	rect_min_size.y = Global.animation_timeline.cel_size
	visibility_button = find_node("VisibilityButton")
	lock_button = find_node("LockButton")
	linked_button = find_node("LinkButton")
	label = find_node("Label")
	line_edit = find_node("LineEdit")

	var layer_buttons = find_node("LayerButtons")
	for child in layer_buttons.get_children():
		var texture = child.get_child(0)
		var last_backslash = texture.texture.resource_path.get_base_dir().find_last("/")
		var button_category = texture.texture.resource_path.get_base_dir().right(last_backslash + 1)
		var normal_file_name = texture.texture.resource_path.get_file()
		var theme_type := Global.theme_type
		if theme_type == Global.ThemeTypes.CARAMEL or theme_type == Global.ThemeTypes.BLUE:
			theme_type = Global.ThemeTypes.DARK

		var theme_type_string : String = Global.ThemeTypes.keys()[theme_type].to_lower()
		texture.texture = load("res://assets/graphics/%s_themes/%s/%s" % [theme_type_string, button_category, normal_file_name])

	if Global.current_project.layers[i].visible:
		Global.change_button_texturerect(visibility_button.get_child(0), "layer_visible.png")
		visibility_button.get_child(0).rect_size = Vector2(24, 14)
		visibility_button.get_child(0).rect_position = Vector2(4, 9)
	else:
		Global.change_button_texturerect(visibility_button.get_child(0), "layer_invisible.png")
		visibility_button.get_child(0).rect_size = Vector2(24, 8)
		visibility_button.get_child(0).rect_position = Vector2(4, 12)

	if Global.current_project.layers[i].locked:
		Global.change_button_texturerect(lock_button.get_child(0), "lock.png")
	else:
		Global.change_button_texturerect(lock_button.get_child(0), "unlock.png")

	if Global.current_project.layers[i].new_cels_linked: # If new layers will be linked
		Global.change_button_texturerect(linked_button.get_child(0), "linked_layer.png")
	else:
		Global.change_button_texturerect(linked_button.get_child(0), "unlinked_layer.png")


func _input(event : InputEvent) -> void:
	if (event.is_action_released("ui_accept") or event.is_action_released("ui_cancel")) and line_edit.visible and event.scancode != KEY_SPACE:
		save_layer_name(line_edit.text)


func _on_LayerContainer_pressed() -> void:
	pressed = !pressed
	label.visible = false
	line_edit.visible = true
	line_edit.editable = true
	line_edit.grab_focus()


func _on_LineEdit_focus_exited() -> void:
	save_layer_name(line_edit.text)


func save_layer_name(new_name : String) -> void:
	label.visible = true
	line_edit.visible = false
	line_edit.editable = false
	label.text = new_name
	Global.layers_changed_skip = true
	Global.current_project.layers[i].name = new_name


func _on_VisibilityButton_pressed() -> void:
	Global.current_project.layers[i].visible = !Global.current_project.layers[i].visible
	Global.canvas.update()


func _on_LockButton_pressed() -> void:
	Global.current_project.layers[i].locked = !Global.current_project.layers[i].locked


func _on_LinkButton_pressed() -> void:
	Global.current_project.layers[i].new_cels_linked = !Global.current_project.layers[i].new_cels_linked
	if Global.current_project.layers[i].new_cels_linked && !Global.current_project.layers[i].linked_cels:
		# If button is pressed and there are no linked cels in the layer
		Global.current_project.layers[i].linked_cels.append(Global.current_project.frames[Global.current_project.current_frame])
		Global.current_project.layers[i].frame_container.get_child(Global.current_project.current_frame)._ready()
