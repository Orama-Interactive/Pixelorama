extends Button

onready var properties = $DialogContainer/Properties


func _on_LineButton_pressed():
	properties.popup(Rect2(rect_global_position, properties.rect_size))
	Global.dialog_open(true)


func _on_Properties_popup_hide():
	Global.dialog_open(false)
