class_name LayerContainer
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

	if Global.layers[i][1]:
		visibility_button.texture_normal = load("res://Assets/Graphics/%s Themes/Layers/Layer_Visible.png" % Global.theme_type)
		visibility_button.texture_hover = load("res://Assets/Graphics/%s Themes/Layers/Layer_Visible_Hover.png" % Global.theme_type)
	else:
		visibility_button.texture_normal = load("res://Assets/Graphics/%s Themes/Layers/Layer_Invisible.png" % Global.theme_type)
		visibility_button.texture_hover = load("res://Assets/Graphics/%s Themes/Layers/Layer_Invisible_Hover.png" % Global.theme_type)

	if Global.layers[i][2]:
		lock_button.texture_normal = load("res://Assets/Graphics/%s Themes/Layers/Lock.png" % Global.theme_type)
		lock_button.texture_hover = load("res://Assets/Graphics/%s Themes/Layers/Lock_Hover.png" % Global.theme_type)
	else:
		lock_button.texture_normal = load("res://Assets/Graphics/%s Themes/Layers/Unlock.png" % Global.theme_type)
		lock_button.texture_hover = load("res://Assets/Graphics/%s Themes/Layers/Unlock_Hover.png" % Global.theme_type)

	if Global.layers[i][4]: # If new layers will be linked
		linked_button.texture_normal = load("res://Assets/Graphics/%s Themes/Layers/Linked_Layer.png" % Global.theme_type)
		linked_button.texture_hover = load("res://Assets/Graphics/%s Themes/Layers/Linked_Layer_Hover.png" % Global.theme_type)
	else:
		linked_button.texture_normal = load("res://Assets/Graphics/%s Themes/Layers/Unlinked_Layer.png" % Global.theme_type)
		linked_button.texture_hover = load("res://Assets/Graphics/%s Themes/Layers/Unlinked_Layer_Hover.png" % Global.theme_type)


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
	Global.layers[i][0] = new_name


func _on_VisibilityButton_pressed() -> void:
	Global.layers[i][1] = !Global.layers[i][1]
	Global.canvas.update()


func _on_LockButton_pressed() -> void:
	Global.layers[i][2] = !Global.layers[i][2]


func _on_LinkButton_pressed() -> void:
	Global.layers[i][4] = !Global.layers[i][4]
	if Global.layers[i][4] && !Global.layers[i][5]:
		Global.layers[i][5].append(Global.canvas)
		Global.layers[i][3].get_child(Global.current_frame)._ready()
