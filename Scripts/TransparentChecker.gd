extends ColorRect


func _ready():
	rect_size = Global.canvas.size
	material.set_shader_param("size", Global.checker_size)
	material.set_shader_param("color1", Global.checker_color_1)
	material.set_shader_param("color2", Global.checker_color_2)
