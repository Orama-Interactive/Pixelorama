extends FileDialog

var new_frame := true
var import_spritesheet := false
var spritesheet_horizontal := 1
var spritesheet_vertical := 1

func _ready() -> void:
	var children := []
	for i in range(get_child_count()):
		if i > 7:
			children.append(get_child(i))

	for child in children:
		remove_child(child)
		get_vbox().add_child(child)


func _on_ImportAsNewFrame_pressed() -> void:
	new_frame = !new_frame


func _on_ImportSpritesheet_pressed() -> void:
	import_spritesheet = !import_spritesheet
	var spritesheet_container = Global.find_node_by_name(self, "Spritesheet")
	spritesheet_container.visible = import_spritesheet


func _on_HorizontalFrames_value_changed(value) -> void:
	spritesheet_horizontal = value


func _on_VerticalFrames_value_changed(value) -> void:
	spritesheet_vertical = value


func _on_ImportSprites_files_selected(paths : PoolStringArray) ->  void:
	Global.control.opensprite_file_selected = true
	if !new_frame: # If we're not adding a new frame, delete the previous
		Global.clear_canvases()
		Global.layers.clear()
		# Store [Layer name (0), Layer visibility boolean (1), Layer lock boolean (2), Frame container (3),
		# will new frames be linked boolean (4), Array of linked frames (5)]
		Global.layers.append(Layer.new())
		Global.current_layer = 0

	var first_path : String = paths[0]
	var i : int = Global.canvases.size()
	if !import_spritesheet:
		# Find the biggest image and let it handle the camera zoom options
		var max_size : Vector2
		var biggest_canvas : Canvas
		for path in paths:
			var image := Image.new()
			var err := image.load(path)
			if err != OK: # An error occured
				var file_name : String = path.get_file()
				Global.error_dialog.set_text(tr("Can't load file '%s'.\nError code: %s") % [file_name, str(err)])
				Global.error_dialog.popup_centered()
				Global.dialog_open(true)
				continue

			var canvas : Canvas = load("res://src/Canvas.tscn").instance()
			canvas.size = image.get_size()
			image.convert(Image.FORMAT_RGBA8)
			image.lock()
			var tex := ImageTexture.new()
			tex.create_from_image(image, 0)
			# Store [Image, ImageTexture, Opacity]
			canvas.layers.append([image, tex, 1])

			for _i in range(1, Global.layers.size()):
				var empty_sprite := Image.new()
				empty_sprite.create(canvas.size.x, canvas.size.y, false, Image.FORMAT_RGBA8)
				empty_sprite.fill(Color(0, 0, 0, 0))
				empty_sprite.lock()

				var empty_tex := ImageTexture.new()
				empty_tex.create_from_image(empty_sprite, 0)

				# Store [Image, ImageTexture, Opacity]
				canvas.layers.append([empty_sprite, empty_tex, 1])

			canvas.frame = i
			Global.canvases.append(canvas)
			Global.canvas_parent.add_child(canvas)
			canvas.visible = false
			if path == paths[0]: # If it's the first file
				max_size = canvas.size
				biggest_canvas = canvas
			else:
				if canvas.size > max_size:
					biggest_canvas = canvas

			i += 1

		if biggest_canvas:
			biggest_canvas.camera_zoom()

	else:
		var image := Image.new()
		var err := image.load(first_path)
		if err != OK: # An error occured
			var file_name : String = first_path.get_file()
			Global.error_dialog.set_text(tr("Can't load file '%s'.\nError code: %s") % [file_name, str(err)])
			Global.error_dialog.popup_centered()
			Global.dialog_open(true)
			return

		spritesheet_horizontal = min(spritesheet_horizontal, image.get_size().x)
		spritesheet_vertical = min(spritesheet_vertical, image.get_size().y)
		var frame_width := image.get_size().x / spritesheet_horizontal
		var frame_height := image.get_size().y / spritesheet_vertical
		for yy in range(spritesheet_vertical):
			for xx in range(spritesheet_horizontal):
				var canvas : Canvas = load("res://src/Canvas.tscn").instance()
				var cropped_image := Image.new()
				cropped_image = image.get_rect(Rect2(frame_width * xx, frame_height * yy, frame_width, frame_height))
				canvas.size = cropped_image.get_size()
				cropped_image.convert(Image.FORMAT_RGBA8)
				cropped_image.lock()
				var tex := ImageTexture.new()
				tex.create_from_image(cropped_image, 0)
				# Store [Image, ImageTexture, Opacity]
				canvas.layers.append([cropped_image, tex, 1])
				for _i in range(1, Global.layers.size()):
					var empty_sprite := Image.new()
					empty_sprite.create(canvas.size.x, canvas.size.y, false, Image.FORMAT_RGBA8)
					empty_sprite.fill(Color(0, 0, 0, 0))
					empty_sprite.lock()

					var empty_tex := ImageTexture.new()
					empty_tex.create_from_image(empty_sprite, 0)

					# Store [Image, ImageTexture, Opacity]
					canvas.layers.append([empty_sprite, empty_tex, 1])

				canvas.frame = i
				Global.canvases.append(canvas)
				Global.canvas_parent.add_child(canvas)
				canvas.visible = false

				i += 1

		Global.canvases[Global.canvases.size() - 1].camera_zoom()

	Global.canvases = Global.canvases # Just to call Global.canvases_changed
	Global.current_frame = i - 1
	Global.canvas = Global.canvases[Global.canvases.size() - 1]
	if !new_frame:
		Global.layers = Global.layers # Just to call Global.layers_changed
	Global.canvas.visible = true

	Global.window_title = first_path.get_file() + " (" + tr("imported") + ") - Pixelorama " + Global.current_version
	if Global.project_has_changed:
		Global.window_title = Global.window_title + "(*)"
	var file_name := first_path.get_basename().get_file()
	var directory_path := first_path.get_basename().replace(file_name, "")
	Global.export_dialog.directory_path = directory_path
	Global.export_dialog.file_name = file_name

