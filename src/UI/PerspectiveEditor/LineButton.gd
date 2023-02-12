extends Button

onready var length_slider = $"%LengthSlider"


func _ready():
	var p_size = Global.current_project.size
	var suitable_length = sqrt(pow(p_size.x, 2) + pow(p_size.y, 2))
	length_slider.max_value = suitable_length
