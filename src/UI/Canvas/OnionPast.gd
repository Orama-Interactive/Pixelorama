extends Node2D


func _draw() -> void:
	if Global.onion_skinning:
		if Global.onion_skinning_past_rate > 0:
			var color: Color
			if Global.onion_skinning_blue_red:
				color = Color.blue
			else:
				color = Color.white
			for i in range(1, Global.onion_skinning_past_rate + 1):
				if Global.current_project.current_frame >= i:
					var layer_i := 0
					for layer in Global.current_project.frames[Global.current_project.current_frame - i].cels:
						if Global.current_project.layers[layer_i].visible:
							#ignore layer if it has "onion_ignore" in its name (case in-sensitive).
							if not "ignore_onion" in Global.current_project.layers[layer_i].name.to_lower():
								color.a = 0.6 / i
								draw_texture(layer.image_texture, Vector2.ZERO, color)
								update()
						layer_i += 1
