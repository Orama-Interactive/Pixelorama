extends Button

## This is NOT related to the CollapsibleContainer class (though it behaves similarly)
## It was done like this because the "Content" is part of a different node

@export var point_text := "":
	set(value):
		$Label.text = value
		custom_minimum_size = $Label.size
@export var visible_content := false:
	set(value):
		visible_content = value
		button_pressed = value
@onready var content := $"%Content"


func _ready() -> void:
	_set_visible(button_pressed)
	content.visibility_changed.connect(_child_visibility_changed)


func _on_Button_toggled(press: bool) -> void:
	_set_visible(press)


func _set_visible(press: bool) -> void:
	if press:
		$TextureRect.rotation = 0
	else:
		$TextureRect.rotation = -PI / 2
	content.visible = press


## Checks if a child becomes visible from another source and ensures
## it remains invisible if the button is not pressed
func _child_visibility_changed() -> void:
	if not button_pressed:
		content.visible = false
