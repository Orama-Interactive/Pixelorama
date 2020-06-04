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
		Global.clear_frames()
		Global.current_project.layers.clear()
		Global.current_project.layers.append(Layer.new())
		Global.current_project.current_layer = 0

	var first_path : String = paths[0]
	var i : int = Global.current_project.frames.size()
	if !import_spritesheet:
		for path in paths:
			var image := Image.new()
			var err := image.load(path)
			if err != OK: # An error occured
				var file_name : String = path.get_file()
				Global.error_dialog.set_text(tr("Can't load file '%s'.\nError code: %s") % [file_name, str(err)])
				Global.error_dialog.popup_centered()
				Global.dialog_open(true)
				continue

			Global.current_project.size = image.get_size()
			var frame := Frame.new()
			image.convert(Image.FORMAT_RGBA8)
			image.lock()
			frame.cels.append(Cel.new(image, 1))

			for _i in range(1, Global.current_project.layers.size()):
				var empty_sprite := Image.new()
				empty_sprite.create(Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_RGBA8)
				empty_sprite.fill(Color(0, 0, 0, 0))
				empty_sprite.lock()
				frame.cels.append(Cel.new(empty_sprite, 1))

			Global.current_project.frames.append(frame)

			i += 1

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
				var frame := Frame.new()
				var cropped_image := Image.new()
				cropped_image = image.get_rect(Rect2(frame_width * xx, frame_height * yy, frame_width, frame_height))
				Global.current_project.size = cropped_image.get_size()
				cropped_image.convert(Image.FORMAT_RGBA8)
				cropped_image.lock()
				frame.cels.append(Cel.new(cropped_image, 1))

				for _i in range(1, Global.current_project.layers.size()):
					var empty_sprite := Image.new()
					empty_sprite.create(Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_RGBA8)
					empty_sprite.fill(Color(0, 0, 0, 0))
					empty_sprite.lock()
					frame.cels.append(Cel.new(empty_sprite, 1))

				Global.current_project.frames.append(frame)

				i += 1

	Global.canvas.camera_zoom()

	Global.current_project.frames = Global.current_project.frames # Just to call Global.frames_changed
	Global.current_project.current_frame = i - 1
	if !new_frame:
		Global.current_project.layers = Global.current_project.layers # Just to call Global.layers_changed

	Global.window_title = first_path.get_file() + " (" + tr("imported") + ") - Pixelorama " + Global.current_version
	if Global.current_project.has_changed:
		Global.window_title = Global.window_title + "(*)"
	var file_name := first_path.get_basename().get_file()
	var directory_path := first_path.get_basename().replace(file_name, "")
	Global.export_dialog.directory_path = directory_path
	Global.export_dialog.file_name = file_name
