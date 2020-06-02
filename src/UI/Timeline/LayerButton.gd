class_name LayerButton
extends Button

var i := 0
var visibility_button : BaseButton
var lock_button : BaseButton
var linked_button : BaseButton
var label : Label
var line_edit : LineEdit


func _ready() -> void:
	visibility_button = Global.find_node_by_name(self, "VisibilityButton")
	lock_button = Global.find_node_by_name(self, "LockButton")
	linked_button = Global.find_node_by_name(self, "LinkButton")
	label = Global.find_node_by_name(self, "Label")
	line_edit = Global.find_node_by_name(self, "LineEdit")

	if Global.layers[i].visible:
		Global.change_button_texturerect(visibility_button.get_child(0), "layer_visible.png")
		visibility_button.get_child(0).rect_size = Vector2(24, 14)
		visibility_button.get_child(0).rect_position = Vector2(4, 9)
	else:
		Global.change_button_texturerect(visibility_button.get_child(0), "layer_invisible.png")
		visibility_button.get_child(0).rect_size = Vector2(24, 8)
		visibility_button.get_child(0).rect_position = Vector2(4, 12)

	if Global.layers[i].locked:
		Global.change_button_texturerect(lock_button.get_child(0), "lock.png")
	else:
		Global.change_button_texturerect(lock_button.get_child(0), "unlock.png")

	if Global.layers[i].new_cels_linked: # If new layers will be linked
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
	Global.layers[i].name = new_name


func _on_VisibilityButton_pressed() -> void:
	Global.layers[i].visible = !Global.layers[i].visible
	Global.canvas.update()


func _on_LockButton_pressed() -> void:
	Global.layers[i].locked = !Global.layers[i].locked


func _on_LinkButton_pressed() -> void:
	Global.layers[i].new_cels_linked = !Global.layers[i].new_cels_linked
	if Global.layers[i].new_cels_linked && !Global.layers[i].linked_cels:
		# If button is pressed and there are no linked cels in the layer
		Global.layers[i].linked_cels.append(Global.frames[Global.current_frame])
		Global.layers[i].frame_container.get_child(Global.current_frame)._ready()
