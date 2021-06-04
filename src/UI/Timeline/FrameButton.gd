extends Button


var frame := 0


func _ready() -> void:
	connect("pressed", self, "_button_pressed")


func _button_pressed() -> void:
	Global.current_project.current_frame = frame
