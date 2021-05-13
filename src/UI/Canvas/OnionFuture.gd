extends Node2D


func _draw() -> void:
	if Global.onion_skinning:
		if Global.onion_skinning_future_rate > 0:
			var color : Color
			if Global.onion_skinning_blue_red:
				color = Color.red
			else:
				color = Color.white
			for i in range(1, Global.onion_skinning_future_rate + 1):
				if Global.current_project.current_frame < Global.current_project.frames.size() - i:
					var layer_i := 0
					for layer in Global.current_project.frames[Global.current_project.current_frame + i].cels:
						if Global.current_project.layers[layer_i].visible:
							color.a = 0.6 / i
							draw_texture(layer.image_texture, Vector2.ZERO, color)
							update()
						layer_i += 1
