extends ConfirmationDialog

func _on_OutlineDialog_confirmed() -> void:
	var outline_color : Color = $OptionsContainer/OutlineColor.color
	var thickness : int = $OptionsContainer/ThickValue.value
	var diagonal : bool = $OptionsContainer/DiagonalCheckBox.pressed

	var image : Image = Global.canvas.layers[Global.canvas.current_layer_index][0]
	if image.is_invisible():
		return
	var new_image := Image.new()
	new_image.copy_from(image)
	new_image.lock()

	Global.canvas.handle_undo("Draw")
	for xx in image.get_size().x:
		for yy in image.get_size().y:
			var pos = Vector2(xx, yy)
			var current_pixel := image.get_pixelv(pos)
			if current_pixel.a == 0:
				continue

			for i in range(1, thickness + 1):
				var new_pos : Vector2 = pos + Vector2.LEFT * i # Left
				if new_pos.x >= 0:
					var new_pixel = image.get_pixelv(new_pos)
					if new_pixel.a == 0:
						new_image.set_pixelv(new_pos, outline_color)

				new_pos = pos + Vector2.RIGHT * i # Right
				if new_pos.x < Global.canvas.size.x:
					var new_pixel = image.get_pixelv(new_pos)
					if new_pixel.a == 0:
						new_image.set_pixelv(new_pos, outline_color)

				new_pos = pos + Vector2.UP * i # Up
				if new_pos.y >= 0:
					var new_pixel = image.get_pixelv(new_pos)
					if new_pixel.a == 0:
						new_image.set_pixelv(new_pos, outline_color)

				new_pos = pos + Vector2.DOWN * i # Down
				if new_pos.y < Global.canvas.size.y:
					var new_pixel = image.get_pixelv(new_pos)
					if new_pixel.a == 0:
						new_image.set_pixelv(new_pos, outline_color)

				if diagonal:
					new_pos = pos + (Vector2.LEFT + Vector2.UP) * i # Top left
					if new_pos.x >= 0 && new_pos.y >= 0:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a == 0:
							new_image.set_pixelv(new_pos, outline_color)

					new_pos = pos + (Vector2.LEFT + Vector2.DOWN) * i # Bottom left
					if new_pos.x >= 0 && new_pos.y < Global.canvas.size.y:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a == 0:
							new_image.set_pixelv(new_pos, outline_color)

					new_pos = pos + (Vector2.RIGHT + Vector2.UP) * i # Top right
					if new_pos.x < Global.canvas.size.x && new_pos.y >= 0:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a == 0:
							new_image.set_pixelv(new_pos, outline_color)

					new_pos = pos + (Vector2.RIGHT + Vector2.DOWN) * i # Bottom right
					if new_pos.x < Global.canvas.size.x && new_pos.y < Global.canvas.size.y:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a == 0:
							new_image.set_pixelv(new_pos, outline_color)

	image.copy_from(new_image)
	Global.canvas.handle_redo("Draw")
