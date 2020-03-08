class_name LayerContainer
extends Button

var i := 0
var visibility_button : BaseButton
var label : Label
var line_edit : LineEdit

func _ready() -> void:
	visibility_button = Global.find_node_by_name(self, "VisibilityButton")
	label = Global.find_node_by_name(self, "Label")
	line_edit = Global.find_node_by_name(self, "LineEdit")

	if Global.layers[i][1]:
		visibility_button.texture_normal = load("res://Assets/Graphics/%s Themes/Layers/Layer_Visible.png" % Global.theme_type)
		visibility_button.texture_hover = load("res://Assets/Graphics/%s Themes/Layers/Layer_Visible_Hover.png" % Global.theme_type)
	else:
		visibility_button.texture_normal = load("res://Assets/Graphics/%s Themes/Layers/Layer_Invisible.png" % Global.theme_type)
		visibility_button.texture_hover = load("res://Assets/Graphics/%s Themes/Layers/Layer_Invisible_Hover.png" % Global.theme_type)

func _input(event : InputEvent) -> void:
	if event.is_action_released("ui_accept") && line_edit.visible && event.scancode != KEY_SPACE:
		label.visible = true
		line_edit.visible = false
		line_edit.editable = false
		var new_text : String = line_edit.text
		label.text = new_text
		Global.layers[i][0] = new_text

func _on_LayerContainer_pressed() -> void:
	pressed = !pressed
	var label_initially_visible : bool = label.visible

	if label_initially_visible:
		label.visible = false
		line_edit.visible = true
		line_edit.editable = true
		line_edit.grab_focus()
	else:
		label.visible = true
		line_edit.visible = false
		line_edit.editable = false

func _on_VisibilityButton_pressed() -> void:
	if Global.layers[i][1]:
		Global.layers[i][1] = false
		visibility_button.texture_normal = load("res://Assets/Graphics/%s Themes/Layers/Layer_Invisible.png" % Global.theme_type)
		visibility_button.texture_hover = load("res://Assets/Graphics/%s Themes/Layers/Layer_Invisible_Hover.png" % Global.theme_type)
	else:
		Global.layers[i][1] = true
		visibility_button.texture_normal = load("res://Assets/Graphics/%s Themes/Layers/Layer_Visible.png" % Global.theme_type)
		visibility_button.texture_hover = load("res://Assets/Graphics/%s Themes/Layers/Layer_Visible_Hover.png" % Global.theme_type)
	Global.canvas.update()
