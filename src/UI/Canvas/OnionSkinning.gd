extends Node2D

enum { PAST, FUTURE }

var type := PAST
var blue_red_color := Color.blue
var rate := Global.onion_skinning_past_rate


func _draw() -> void:
	if !Global.onion_skinning:
		return

	rate = Global.onion_skinning_past_rate if type == PAST else Global.onion_skinning_future_rate
	if rate > 0:
		var color: Color
		if Global.onion_skinning_blue_red:
			color = blue_red_color
		else:
			color = Color.white
		for i in range(1, rate + 1):
			var change = Global.current_project.current_frame
			if type == PAST:
				change -= i
			else:
				change += i
			if change == clamp(change, 0, Global.current_project.frames.size() - 1):
				var layer_i := 0
				for layer in Global.current_project.frames[change].cels:
					if Global.current_project.layers[layer_i].visible:
						# Ignore layer if it has "onion_ignore" in its name (case in-sensitive)
						if not (
							"ignore_onion"
							in Global.current_project.layers[layer_i].name.to_lower()
						):
							color.a = 0.6 / i
							draw_texture(layer.image_texture, Vector2.ZERO, color)
					layer_i += 1
