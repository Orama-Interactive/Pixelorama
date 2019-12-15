extends Button
class_name LayerContainer

var i
# warning-ignore:unused_class_variable
var currently_selected := false

onready var visibility_button := $VisibilityButton
onready var label := $HBoxContainer/Label
onready var line_edit := $HBoxContainer/LineEdit

func _ready() -> void:
	changed_selection()

func _input(event : InputEvent):
	if event.is_action_released("ui_accept") && line_edit.visible && event.scancode != KEY_SPACE:
		label.visible = true
		line_edit.visible = false
		line_edit.editable = false

func _on_LayerContainer_pressed() -> void:
	var initially_pressed := pressed
	var label_initially_visible : bool = label.visible
	Global.canvas.current_layer_index = i
	changed_selection()
	if !initially_pressed:
		if label_initially_visible:
			label.visible = false
			line_edit.visible = true
			line_edit.editable = true
			line_edit.grab_focus()
		else:
			label.visible = true
			line_edit.visible = false
			line_edit.editable = false

func changed_selection() -> void:
	var parent := get_parent()
	for child in parent.get_children():
		if child is Button:
			child.label.visible = true
			child.line_edit.visible = false
			child.line_edit.editable = false
			if Global.canvas.current_layer_index == child.i:
				child.currently_selected = true
				child.pressed = true

				if Global.canvas.current_layer_index < Global.canvas.layers.size() - 1:
					Global.move_up_layer_button.disabled = false
					Global.move_up_layer_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				else:
					Global.move_up_layer_button.disabled = true
					Global.move_up_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

				if Global.canvas.current_layer_index > 0:
					Global.move_down_layer_button.disabled = false
					Global.move_down_layer_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					Global.merge_down_layer_button.disabled = false
					Global.merge_down_layer_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				else:
					Global.move_down_layer_button.disabled = true
					Global.move_down_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
					Global.merge_down_layer_button.disabled = true
					Global.merge_down_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
			else:
				child.currently_selected = false
				child.pressed = false

func _on_VisibilityButton_pressed() -> void:
	if Global.canvas.layers[i][3]:
		Global.canvas.layers[i][3] = false
		visibility_button.texture_normal = preload("res://Assets/Graphics/Layers/layer_invisible.png")
	else:
		Global.canvas.layers[i][3] = true
		visibility_button.texture_normal = preload("res://Assets/Graphics/Layers/layer_visible.png")

func _on_LineEdit_text_changed(new_text : String) -> void:
	Global.canvas.layers[i][2] = new_text
	label.text = new_text