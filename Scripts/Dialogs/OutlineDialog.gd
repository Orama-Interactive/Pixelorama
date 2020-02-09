extends ConfirmationDialog

func _on_OutlineDialog_confirmed() -> void:
	var outline_color : Color = $OptionsContainer/OutlineColor.color
	var thickness : int = $OptionsContainer/ThickValue.value
	var diagonal : bool = $OptionsContainer/DiagonalCheckBox.pressed
	var inside_image : bool = $OptionsContainer/InsideImageCheckBox.pressed

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
				if inside_image:
					var outline_pos : Vector2 = pos + Vector2.LEFT # Left
					if outline_pos.x < 0 || image.get_pixelv(outline_pos).a == 0:
						var new_pos : Vector2 = pos + Vector2.RIGHT * (i - 1)
						if new_pos.x < Global.canvas.size.x:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a > 0:
								new_image.set_pixelv(new_pos, outline_color)
								pass

					outline_pos = pos + Vector2.RIGHT # Right
					if outline_pos.x >= Global.canvas.size.x || image.get_pixelv(outline_pos).a == 0:
						var new_pos : Vector2 = pos + Vector2.LEFT * (i - 1)
						if new_pos.x >= 0:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a > 0:
								new_image.set_pixelv(new_pos, outline_color)
								pass

					outline_pos = pos + Vector2.UP # Up
					if outline_pos.y < 0 || image.get_pixelv(outline_pos).a == 0:
						var new_pos : Vector2 = pos + Vector2.DOWN * (i - 1)
						if new_pos.y < Global.canvas.size.y:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a > 0:
								new_image.set_pixelv(new_pos, outline_color)
								pass

					outline_pos = pos + Vector2.DOWN # Down
					if outline_pos.y >= Global.canvas.size.y || image.get_pixelv(outline_pos).a == 0:
						var new_pos : Vector2 = pos + Vector2.UP * (i - 1)
						if new_pos.y >= 0:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a > 0:
								new_image.set_pixelv(new_pos, outline_color)
								pass

					if diagonal:
						outline_pos = pos + (Vector2.LEFT + Vector2.UP) # Top left
						if (outline_pos.x < 0 && outline_pos.y < 0) || image.get_pixelv(outline_pos).a == 0:
							var new_pos : Vector2 = pos + (Vector2.RIGHT + Vector2.DOWN) * (i - 1)
							if new_pos.x < Global.canvas.size.x && new_pos.y < Global.canvas.size.y:
								var new_pixel = image.get_pixelv(new_pos)
								if new_pixel.a > 0:
									new_image.set_pixelv(new_pos, outline_color)

						outline_pos = pos + (Vector2.LEFT + Vector2.DOWN) # Bottom left
						if (outline_pos.x < 0 && outline_pos.y >= Global.canvas.size.y) || image.get_pixelv(outline_pos).a == 0:
							var new_pos : Vector2 = pos + (Vector2.RIGHT + Vector2.UP) * (i - 1)
							if new_pos.x < Global.canvas.size.x && new_pos.y >= 0:
								var new_pixel = image.get_pixelv(new_pos)
								if new_pixel.a > 0:
									new_image.set_pixelv(new_pos, outline_color)

						outline_pos = pos + (Vector2.RIGHT + Vector2.UP) # Top right
						if (outline_pos.x >= Global.canvas.size.x && outline_pos.y < 0) || image.get_pixelv(outline_pos).a == 0:
							var new_pos : Vector2 = pos + (Vector2.LEFT + Vector2.DOWN) * (i - 1)
							if new_pos.x >= 0 && new_pos.y < Global.canvas.size.y:
								var new_pixel = image.get_pixelv(new_pos)
								if new_pixel.a > 0:
									new_image.set_pixelv(new_pos, outline_color)

						outline_pos = pos + (Vector2.RIGHT + Vector2.DOWN) # Bottom right
						if (outline_pos.x >= Global.canvas.size.x && outline_pos.y >= Global.canvas.size.y) || image.get_pixelv(outline_pos).a == 0:
							var new_pos : Vector2 = pos + (Vector2.LEFT + Vector2.UP) * (i - 1)
							if new_pos.x >= 0 && new_pos.y >= 0:
								var new_pixel = image.get_pixelv(new_pos)
								if new_pixel.a > 0:
									new_image.set_pixelv(new_pos, outline_color)

				else:
					for x in range(-thickness, thickness+1):
						for y in range(-thickness, thickness+1):
							var new_pos = pos + Vector2(x,y)# * i # Right
							if new_pos.x < Global.canvas.size.x and new_pos.x > -1 and new_pos.y > -1 and new_pos.y < Global.canvas.size.x:
								var new_pixel = image.get_pixelv(new_pos)
								if new_pixel.a == 0:
									new_image.set_pixelv(new_pos, outline_color)
					pass


	image.copy_from(new_image)
	Global.canvas.handle_redo("Draw")
