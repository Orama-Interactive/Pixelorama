extends ColorRect

# TODO: Determine if this class (and its instances) can be deleted...

func _ready():
	mouse_filter = MOUSE_FILTER_IGNORE
	rect_size = Global.current_project.size
	material = Global.current_project.layer_blend_material


#func _draw() -> void:
#	var current_cels: Array = Global.current_project.frames[Global.current_project.current_frame].cels
#	for i in range(Global.current_project.layers.size()):
#		# TODO: Make this work with group layers:
#		if Global.current_project.layers[i] is GroupLayer:
#			continue
#
#		if Global.current_project.layers[i].visible and current_cels[i].opacity > 0:
#			var modulate_color := Color(1, 1, 1, current_cels[i].opacity)
#			draw_texture(current_cels[i].image_texture, Vector2.ZERO, modulate_color)
