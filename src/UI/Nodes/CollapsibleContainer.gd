tool
class_name CollapsibleContainer
extends VBoxContainer

export var text := "" setget _set_text
export var visible_content := false setget _set_visible_content


func _ready() -> void:
	_set_visible($Button.pressed)


func _set_text(value: String) -> void:
	text = value
	$Button/Label.text = value


func _set_visible_content(value: bool) -> void:
	visible_content = value
	$Button.pressed = value


func _on_Button_toggled(button_pressed: bool) -> void:
	_set_visible(button_pressed)


func _set_visible(pressed: bool) -> void:
	if pressed:
		$Button/TextureRect.rect_rotation = 0
	else:
		$Button/TextureRect.rect_rotation = -90
	for child in get_children():
		if child == $Button:
			continue
		child.visible = pressed
