extends Button

onready var properties = $DialogContainer/Properties


func _on_LineButton_pressed():
	var pop_position = rect_global_position
	pop_position.y += rect_size.y * 2
	properties.popup(Rect2(pop_position, properties.rect_size))
	properties.window_title = str("Line ", get_index() + 1, " Properties")
