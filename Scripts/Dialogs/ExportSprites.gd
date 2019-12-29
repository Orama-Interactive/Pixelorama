extends FileDialog

var current_export_path := ""
var export_option := 0
var resize := 100
var interpolation = Image.INTERPOLATE_NEAREST
var spritesheet_rows = 1
var spritesheet_columns = 1

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
	var spritesheet_container = Global.find_node_by_name(self, "Spritesheet")
	if ID > 1:
		spritesheet_container.visible = true
	else:
		spritesheet_container.visible = false

func _on_ResizeValue_value_changed(value) -> void:
	resize = value

func _on_Interpolation_item_selected(ID : int) -> void:
	interpolation = ID

func _on_VerticalFrames_value_changed(value) -> void:
	value = min(value, Global.canvases.size())
	spritesheet_columns = value

	var vertical_frames : SpinBox = Global.find_node_by_name(self, "VerticalFrames")
	vertical_frames.value = spritesheet_columns

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
	elif export_option == 2: # Export all frames as a spritesheet (single file)
		save_spritesheet()

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

	if resize != 100:
		whole_image.resize(whole_image.get_size().x * resize / 100, whole_image.get_size().y * resize / 100, interpolation)
	var err = whole_image.save_png(path)
	if err != OK:
		OS.alert("Can't save file")

func save_spritesheet() -> void:
	spritesheet_rows = ceil(Global.canvases.size() / spritesheet_columns)
	var width = Global.canvas.size.x * spritesheet_rows
	var height = Global.canvas.size.y * spritesheet_columns

	var whole_image := Image.new()
	whole_image.create(width, height, false, Image.FORMAT_RGBA8)
	whole_image.lock()
	var dst := Vector2.ZERO
	var hh := 0
	var vv := 0
	for canvas in Global.canvases:
		if hh < spritesheet_rows:
			dst.x = canvas.size.x * hh
			hh += 1
		else:
			vv += 1
			dst.x = 0
			hh = 1
			dst.y = canvas.size.y * vv

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

	if resize != 100:
		whole_image.resize(width * resize / 100, height * resize / 100, interpolation)
	var err = whole_image.save_png(current_export_path)
	if err != OK:
		OS.alert("Can't save file")
