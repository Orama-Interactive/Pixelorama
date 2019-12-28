extends FileDialog

var current_export_path := ""
var export_option := 0

func _ready() -> void:
	var children := []
	for i in range(get_child_count()):
		if i > 7:
			children.append(get_child(i))

	for child in children:
		remove_child(child)
		get_vbox().add_child(child)

func _on_ExportOption_item_selected(ID : int) -> void:
	export_option = ID

func _on_ExportSprites_file_selected(path : String) -> void:
	current_export_path = path
	Global.file_menu.get_popup().set_item_text(5, tr("Export") + " %s" % path.get_file())
	export_project()

func export_project() -> void:
	if export_option == 0: # Export current frame
		save_sprite(Global.canvas, current_export_path)
	elif export_option == 1: # Export all frames as multiple files
		var i := 1
		for canvas in Global.canvases:
			var path := "%s_%s" % [current_export_path, str(i)]
			path = path.replace(".png", "")
			path = "%s.png" % path
			save_sprite(canvas, path)
			i += 1
	else: # Export all frames as a spritesheet (single file)
		save_spritesheet(export_option == 2)

	Global.notification_label("File exported")

func save_sprite(canvas : Canvas, path : String) -> void:
	var whole_image := Image.new()
	whole_image.create(canvas.size.x, canvas.size.y, false, Image.FORMAT_RGBA8)
	whole_image.lock()
	for layer in canvas.layers:
		var img : Image = layer[0]
		img.lock()
		if layer[4] < 1: # If we have layer transparency
			for xx in img.get_size().x:
				for yy in img.get_size().y:
					var pixel_color := img.get_pixel(xx, yy)
					var alpha : float = pixel_color.a * layer[4]
					img.set_pixel(xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha))

		canvas.blend_rect(whole_image, img, Rect2(canvas.position, canvas.size), Vector2.ZERO)
		layer[0].lock()
	var err = whole_image.save_png(path)
	if err != OK:
		OS.alert("Can't save file")

func save_spritesheet(horizontal : bool) -> void:
	var width
	var height
	if horizontal: # Horizontal spritesheet
		width = 0
		height = Global.canvas.size.y
		for canvas in Global.canvases:
			width += canvas.size.x
			if canvas.size.y > height:
				height = canvas.size.y
	else: # Vertical spritesheet
		width = Global.canvas.size.x
		height = 0
		for canvas in Global.canvases:
			height += canvas.size.y
			if canvas.size.x > width:
				width = canvas.size.x

	var whole_image := Image.new()
	whole_image.create(width, height, false, Image.FORMAT_RGBA8)
	whole_image.lock()
	var dst := Vector2.ZERO
	for canvas in Global.canvases:
		for layer in canvas.layers:
			var img : Image = layer[0]
			img.lock()
			if layer[4] < 1: # If we have layer transparency
				for xx in img.get_size().x:
					for yy in img.get_size().y:
						var pixel_color := img.get_pixel(xx, yy)
						var alpha : float = pixel_color.a * layer[4]
						img.set_pixel(xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha))

			canvas.blend_rect(whole_image, img, Rect2(canvas.position, canvas.size), dst)
			layer[0].lock()

		if horizontal:
			dst += Vector2(canvas.size.x, 0)
		else:
			dst += Vector2(0, canvas.size.y)

	var err = whole_image.save_png(current_export_path)
	if err != OK:
		OS.alert("Can't save file")

