extends AcceptDialog

enum ExportTab { Frame = 0, Spritesheet = 1, Animation = 2 }
var current_tab : int = ExportTab.Frame

# All canvases and their layers processed/blended into images
var processed_images = [] # Image[]

# Frame options
var frame_number := 0

# Spritesheet options
enum Orientation { Rows = 0, Columns = 1 }
var orientation : int = Orientation.Rows
# How many rows/columns before new line is added
var lines_count := 1

# Animation options
enum AnimationType { MultipleFiles = 0 }
var animation_type : int = AnimationType.MultipleFiles

# Options
var resize := 100
var interpolation := 0 # Image.Interpolation

# Export directory path and export file name
var directory_path := ""
var file_name := ""
var file_format := ".png"

var file_exists_alert = "File %s already exists. Overwrite?"

# Store all settings after export, enables a quick re-export with same settings
var was_exported : bool = false
var exported_tab : int
var exported_frame_number : int
var exported_orientation : int
var exported_lines_count : int
var exported_animation_type : int
var exported_resize : int
var exported_interpolation : int
var exported_directory_path : String
var exported_file_name : String
var exported_file_format : String

# Export coroutine signal
signal resume_export_function()
var stop_export = false

func _ready() -> void:
	$VBoxContainer/Tabs.add_tab("Frame")
	$VBoxContainer/Tabs.add_tab("Spritesheet")
	$VBoxContainer/Tabs.add_tab("Animation")
	if OS.get_name() == "Windows":
		add_button("Cancel", true, "cancel")
		$Popups/FileExistsAlert.add_button("Cancel Export", true, "cancel")
	else:
		add_button("Cancel", false, "cancel")
		$Popups/FileExistsAlert.add_button("Cancel Export", false, "cancel")

func show_tab() -> void:
	$VBoxContainer/FrameOptions.hide()
	$VBoxContainer/SpritesheetOptions.hide()
	$VBoxContainer/AnimationOptions.hide()

	match current_tab:
		ExportTab.Frame:
			if not was_exported:
				frame_number = Global.current_frame + 1
			$VBoxContainer/FrameOptions/FrameNumber/FrameNumber.max_value = Global.canvases.size() + 1
			$VBoxContainer/FrameOptions/FrameNumber/FrameNumber.value = frame_number
			process_frame()
			$VBoxContainer/FrameOptions.show()
		ExportTab.Spritesheet:
			if not was_exported:
				orientation = Orientation.Rows
				lines_count = int(ceil(sqrt(Global.canvases.size())))
			$VBoxContainer/SpritesheetOptions/Orientation/Orientation.selected = orientation
			$VBoxContainer/SpritesheetOptions/Orientation/LinesCount.max_value = Global.canvases.size()
			$VBoxContainer/SpritesheetOptions/Orientation/LinesCount.value = lines_count
			$VBoxContainer/SpritesheetOptions/Orientation/LinesCountLabel.text = "Columns:"
			process_spritesheet()
			$VBoxContainer/SpritesheetOptions.show()
		ExportTab.Animation:
			process_animation()
			$VBoxContainer/AnimationOptions.show()
	set_preview()
	$VBoxContainer/Tabs.current_tab = current_tab


func external_export() -> void:
	restore_previous_export_settings()
	match current_tab:
		ExportTab.Frame:
			process_frame()
		ExportTab.Spritesheet:
			process_spritesheet()
		ExportTab.Animation:
			process_animation()
	export_processed_images(true)


func process_frame() -> void:
	var canvas = Global.canvases[frame_number - 1]
	var image := Image.new()
	image.create(canvas.size.x, canvas.size.y, false, Image.FORMAT_RGBA8)
	blend_layers(image, canvas)
	processed_images.clear()
	processed_images.append(image)


func process_spritesheet() -> void:
	# If rows mode selected calculate columns count and vice versa
	var spritesheet_columns = lines_count if orientation == Orientation.Rows else frames_divided_by_spritesheet_lines()
	var spritesheet_rows = lines_count if orientation == Orientation.Columns else frames_divided_by_spritesheet_lines()

	var width = Global.canvas.size.x * spritesheet_columns
	var height = Global.canvas.size.y * spritesheet_rows

	var whole_image := Image.new()
	whole_image.create(width, height, false, Image.FORMAT_RGBA8)
	whole_image.lock()
	var origin := Vector2.ZERO
	var hh := 0
	var vv := 0
	for canvas in Global.canvases:
		if orientation == Orientation.Rows:
			if vv < spritesheet_columns:
				origin.x = canvas.size.x * vv
				vv += 1
			else:
				hh += 1
				origin.x = 0
				vv = 1
				origin.y = canvas.size.y * hh
		else:
			if hh < spritesheet_rows:
				origin.y = canvas.size.y * hh
				hh += 1
			else:
				vv += 1
				origin.y = 0
				hh = 1
				origin.x = canvas.size.x * vv
		blend_layers(whole_image, canvas, origin)

	processed_images.clear()
	processed_images.append(whole_image)


func process_animation() -> void:
	processed_images.clear()
	for canvas in Global.canvases:
		var image := Image.new()
		image.create(canvas.size.x, canvas.size.y, false, Image.FORMAT_RGBA8)
		blend_layers(image, canvas)
		processed_images.append(image)


func set_preview() -> void:
	remove_previews()
	if processed_images.size() == 1 and current_tab != ExportTab.Animation:
		$VBoxContainer/PreviewScroll/Previews.columns = 1
		add_preview(processed_images[0])
	else:
		$VBoxContainer/PreviewScroll/Previews.columns = ceil(sqrt(processed_images.size()))
		for i in range(processed_images.size()):
			add_preview(processed_images[i], i + 1)


func add_preview(image: Image, canvas_number: int = -1) -> void:
	var container = VBoxContainer.new()
	container.size_flags_horizontal = SIZE_EXPAND_FILL
	container.size_flags_vertical = SIZE_EXPAND_FILL
	container.rect_min_size = Vector2(0, 128)

	var preview = TextureRect.new()
	preview.expand = true
	preview.size_flags_horizontal = SIZE_EXPAND_FILL
	preview.size_flags_vertical = SIZE_EXPAND_FILL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = ImageTexture.new()
	preview.texture.create_from_image(image, 0)

	container.add_child(preview)

	if canvas_number != -1:
		var label = Label.new()
		label.align = Label.ALIGN_CENTER
		label.text = String(canvas_number)
		container.add_child(label)

	$VBoxContainer/PreviewScroll/Previews.add_child(container)


func remove_previews() -> void:
	for child in $VBoxContainer/PreviewScroll/Previews.get_children():
		child.queue_free()


func export_processed_images(ignore_overwrites : bool) -> void:
	# Stop export if directory path or file name are not valid
	var dir = Directory.new()
	if not dir.dir_exists(directory_path) or not file_name.is_valid_filename():
		$Popups/PathValidationAlert.popup_centered()
		return

	# Check export paths
	var export_paths = []
	for i in range(processed_images.size()):
		stop_export = false
		var export_path = create_export_path(true if current_tab == ExportTab.Animation else false, i + 1)
		# Check if the file already exists
		var fileCheck = File.new()
		if fileCheck.file_exists(export_path):
			# Ask user if he want's to overwrite the file
			if not was_exported or (was_exported and not ignore_overwrites):
				# Overwrite existing file?
				$Popups/FileExistsAlert.dialog_text = file_exists_alert % export_path
				$Popups/FileExistsAlert.popup_centered()
				# Stops the function until the user decides if he want's to overwrite
				yield(self, "resume_export_function")
				if stop_export:
					# User decided to stop export
					return
		export_paths.append(export_path)

	# Scale images that are to export
	scale_processed_images()

	for i in range(processed_images.size()):
		var err = processed_images[i].save_png(export_paths[i])
		if err != OK:
			OS.alert("Can't save file")

	# Store settings for quick export and when the dialog is opened again
	was_exported = true
	store_export_settings()
	Global.file_menu.get_popup().set_item_text(5, tr("Export") + " %s" % (file_name + file_format))
	Global.notification_label("File(s) exported")
	hide()


# Blends canvas layers into passed image starting from the origin position
func blend_layers(image: Image, canvas: Canvas, origin: Vector2 = Vector2(0, 0)) -> void:
	image.lock()
	var layer_i := 0
	for layer in canvas.layers:
		if Global.layers[layer_i][1]:
			var layer_image : Image = layer[0]
			layer_image.lock()
			if layer[2] < 1: # If we have layer transparency
				for xx in layer_image.get_size().x:
					for yy in layer_image.get_size().y:
						var pixel_color := layer_image.get_pixel(xx, yy)
						var alpha : float = pixel_color.a * layer[2]
						layer_image.set_pixel(xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha))
			canvas.blend_rect(image, layer_image, Rect2(canvas.position, canvas.size), origin)
		layer_i += 1
	image.unlock()


func scale_processed_images() -> void:
	for processed_image in processed_images:
		if resize != 100:
			processed_image.unlock()
			processed_image.resize(processed_image.get_size().x * resize / 100, processed_image.get_size().y * resize / 100, interpolation)


func create_export_path(multifile: bool, frame: int = 0) -> String:
	var path = file_name
	# Only append frame number when there are multiple files exported
	if multifile:
		path += "_" + String(frame)

	return directory_path.plus_file(path + file_format)


func frames_divided_by_spritesheet_lines() -> int:
	return int(ceil(Global.canvases.size() / float(lines_count)))


func store_export_settings() -> void:
	exported_tab = current_tab
	exported_frame_number = frame_number
	exported_orientation = orientation
	exported_lines_count = lines_count
	exported_animation_type = animation_type
	exported_resize = resize
	exported_interpolation = interpolation
	exported_directory_path = directory_path
	exported_file_name = file_name
	exported_file_format = file_format

# Fill the dialog with previous export settings
func restore_previous_export_settings() -> void:
	current_tab = exported_tab
	frame_number = exported_frame_number if exported_frame_number <= Global.canvases.size() else Global.canvases.size()
	orientation = exported_orientation
	lines_count = exported_lines_count
	animation_type = exported_animation_type
	resize = exported_resize
	interpolation = exported_interpolation
	directory_path = exported_directory_path
	file_name = exported_file_name
	file_format = exported_file_format


func _on_ExportDialog_about_to_show() -> void:
	# If export already occured - fill the dialog with previous export settings
	if was_exported:
		restore_previous_export_settings()

	if directory_path.empty():
		directory_path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)

	# If export already occured - sets gui to show previous settings
	$VBoxContainer/Options/Resize.value = resize
	$VBoxContainer/Options/Interpolation.selected = interpolation
	$VBoxContainer/Path/PathLineEdit.text = directory_path
	$VBoxContainer/File/FileLineEdit.text = file_name
	$VBoxContainer/File/FileFormat.text = file_format
	show_tab()

	for child in $Popups.get_children(): # Set the theme for the popups
		child.theme = Global.control.theme

	file_exists_alert = tr("File %s already exists. Overwrite?") # Update translation
	#$VBoxContainer/Tabs.set_tab_title(0, "Frame")

func _on_Tabs_tab_clicked(tab : int) -> void:
	current_tab = tab
	show_tab()


func _on_Frame_value_changed(value: float) -> void:
	frame_number = value
	process_frame()
	set_preview()


func _on_Orientation_item_selected(id : int) -> void:
	orientation = id
	if orientation == Orientation.Rows:
		$VBoxContainer/SpritesheetOptions/Orientation/LinesCountLabel.text = "Columns:"
	else:
		$VBoxContainer/SpritesheetOptions/Orientation/LinesCountLabel.text = "Rows:"
	$VBoxContainer/SpritesheetOptions/Orientation/LinesCount.value = frames_divided_by_spritesheet_lines()
	process_spritesheet()
	set_preview()


func _on_LinesCount_value_changed(value : float) -> void:
	lines_count = value
	process_spritesheet()
	set_preview()


func _on_Resize_value_changed(value : float) -> void:
	resize = value


func _on_Interpolation_item_selected(id: int) -> void:
	interpolation = id


func _on_ExportDialog_confirmed() -> void:
	export_processed_images(false)


func _on_ExportDialog_custom_action(action : String) -> void:
	if action == "cancel":
		hide()


func _on_PathButton_pressed() -> void:
	$Popups/PathDialog.popup_centered()


func _on_PathLineEdit_text_changed(new_text : String) -> void:
	directory_path = new_text


func _on_FileLineEdit_text_changed(new_text : String) -> void:
	file_name = new_text


func _on_FileDialog_dir_selected(dir : String) -> void:
	$VBoxContainer/Path/PathLineEdit.text = dir
	directory_path = dir


func _on_FileFormat_item_selected(id : int) -> void:
	match id:
		0: # PNG
			file_format = '.png'
		1: # GIF
			file_format = '.gif'


func _on_FileExistsAlert_confirmed() -> void:
	# Overwrite existing file
	$Popups/FileExistsAlert.dialog_text = file_exists_alert
	stop_export = false
	emit_signal("resume_export_function")


func _on_FileExistsAlert_custom_action(action : String) -> void:
	if action == "cancel":
		# Cancel export
		$Popups/FileExistsAlert.dialog_text = file_exists_alert
		stop_export = true
		emit_signal("resume_export_function")
		$Popups/FileExistsAlert.hide()
