extends Button

# This is NOT related to the CollapsibleContainer class (though it behaves similarly)
# i did it like this because the "Content" is part of a different node
export var point_text := "" setget _set_text
export var visible_content := false setget _set_visible_content
onready var content = $"%Content"


func _ready() -> void:
	_set_visible(pressed)
	content.connect("visibility_changed", self, "_child_visibility_changed")


func _set_text(value: String) -> void:
	$Label.text = value
	rect_min_size = $Label.rect_size


func _set_visible_content(value: bool) -> void:
	visible_content = value
	pressed = value


func _on_Button_toggled(button_pressed: bool) -> void:
	_set_visible(button_pressed)


func _set_visible(pressed: bool) -> void:
	if pressed:
		$TextureRect.rect_rotation = 0
	else:
		$TextureRect.rect_rotation = -90
	content.visible = pressed


# Checks if a child becomes visible from another source and ensures
# it remains invisible if the button is not pressed
func _child_visibility_changed() -> void:
	if not pressed:
		content.visible = false
