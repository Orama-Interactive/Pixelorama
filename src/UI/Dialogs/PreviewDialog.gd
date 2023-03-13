extends ConfirmationDialog

enum ImageImportOptions {
	NEW_TAB,
	SPRITESHEET_TAB,
	SPRITESHEET_LAYER,
	NEW_FRAME,
	REPLACE_CEL,
	NEW_LAYER,
	NEW_REFERENCE_IMAGE,
	PALETTE,
	BRUSH,
	PATTERN
}
enum BrushTypes { FILE, PROJECT, RANDOM }

var path: String
var image: Image
var current_import_option: int = ImageImportOptions.NEW_TAB
var spritesheet_horizontal := 1
var spritesheet_vertical := 1
var brush_type: int = BrushTypes.FILE
var opened_once = false
var is_master: bool = false
var hiding: bool = false

onready var texture_rect: TextureRect = $VBoxContainer/CenterContainer/TextureRect
onready var image_size_label: Label = $VBoxContainer/SizeContainer/ImageSizeLabel
onready var frame_size_label: Label = $VBoxContainer/SizeContainer/FrameSizeLabel
onready var spritesheet_tab_options = $VBoxContainer/HBoxContainer/SpritesheetTabOptions
onready var spritesheet_lay_opt = $VBoxContainer/HBoxContainer/SpritesheetLayerOptions
onready var new_frame_options = $VBoxContainer/HBoxContainer/NewFrameOptions
onready var replace_cel_options = $VBoxContainer/HBoxContainer/ReplaceCelOptions
onready var new_layer_options = $VBoxContainer/HBoxContainer/NewLayerOptions
onready var new_brush_options = $VBoxContainer/HBoxContainer/NewBrushOptions
onready var new_brush_name = $VBoxContainer/HBoxContainer/NewBrushOptions/BrushName

onready var import_options: OptionButton = $VBoxContainer/HBoxContainer/ImportOption
onready var apply_all: CheckBox = $VBoxContainer/ApplyAll


func _on_PreviewDialog_about_to_show() -> void:
	if opened_once:
		return
	opened_once = true
	# # order as in ImageImportOptions enum
	import_options.add_item("New project")
	import_options.add_item("Spritesheet (new project)")
	import_options.add_item("Spritesheet (new layer)")
	import_options.add_item("New frame")
	import_options.add_item("Replace cel")
	import_options.add_item("New layer")
	import_options.add_item("New reference image")
	import_options.add_item("New palette")
	import_options.add_item("New brush")
	import_options.add_item("New pattern")

	# Select the option that the preview dialog before it had selected
	import_options.select(OpenSave.last_dialog_option)
	import_options.emit_signal("item_selected", OpenSave.last_dialog_option)

	var img_texture := ImageTexture.new()
	img_texture.create_from_image(image, 0)
	texture_rect.texture = img_texture
	spritesheet_tab_options.get_node("HorizontalFrames").max_value = min(
		spritesheet_tab_options.get_node("HorizontalFrames").max_value, image.get_size().x
	)
	spritesheet_tab_options.get_node("VerticalFrames").max_value = min(
		spritesheet_tab_options.get_node("VerticalFrames").max_value, image.get_size().y
	)
	image_size_label.text = (
		tr("Image Size")
		+ ": "
		+ str(image.get_size().x)
		+ "×"
		+ str(image.get_size().y)
	)
	frame_size_label.text = (
		tr("Frame Size")
		+ ": "
		+ str(image.get_size().x)
		+ "×"
		+ str(image.get_size().y)
	)
	if OpenSave.preview_dialogs.size() > 1:
		apply_all.visible = true


func _on_PreviewDialog_popup_hide() -> void:
	if hiding:  # if the popup is hiding because of master
		return
	elif is_master:  # if the master is closed then close others too
		for child in Global.control.get_children():
			if "PreviewDialog" in child.name:
				OpenSave.preview_dialogs.erase(child)
				child.queue_free()
	else:  # dialogs being closed separately
		OpenSave.preview_dialogs.erase(self)
		queue_free()
	# Call Global.dialog_open() only if it's the only preview dialog opened
	if OpenSave.preview_dialogs.size() != 0:
		return
	Global.dialog_open(false)


func _on_PreviewDialog_confirmed() -> void:
	if is_master:  # if the master is confirmed then confirm others too
		is_master = false
		synchronize()
		for child in Global.control.get_children():
			if "PreviewDialog" in child.name:
				child.emit_signal("confirmed")
	else:
		if current_import_option == ImageImportOptions.NEW_TAB:
			OpenSave.open_image_as_new_tab(path, image)

		elif current_import_option == ImageImportOptions.SPRITESHEET_TAB:
			OpenSave.open_image_as_spritesheet_tab(
				path, image, spritesheet_horizontal, spritesheet_vertical
			)

		elif current_import_option == ImageImportOptions.SPRITESHEET_LAYER:
			var frame_index: int = spritesheet_lay_opt.get_node("AtFrameSpinbox").value - 1
			OpenSave.open_image_as_spritesheet_layer(
				path,
				image,
				path.get_basename().get_file(),
				spritesheet_horizontal,
				spritesheet_vertical,
				frame_index
			)

		elif current_import_option == ImageImportOptions.NEW_FRAME:
			var layer_index: int = new_frame_options.get_node("AtLayerOption").get_selected_id()
			OpenSave.open_image_as_new_frame(image, layer_index)

		elif current_import_option == ImageImportOptions.REPLACE_CEL:
			var layer_index: int = replace_cel_options.get_node("AtLayerOption").get_selected_id()
			var frame_index: int = replace_cel_options.get_node("AtFrameSpinbox").value - 1
			OpenSave.open_image_at_cel(image, layer_index, frame_index)

		elif current_import_option == ImageImportOptions.NEW_LAYER:
			var frame_index: int = new_layer_options.get_node("AtFrameSpinbox").value - 1
			OpenSave.open_image_as_new_layer(image, path.get_basename().get_file(), frame_index)

		elif current_import_option == ImageImportOptions.NEW_REFERENCE_IMAGE:
			if OS.get_name() == "HTML5":
				OpenSave.import_reference_image_from_image(image)
			else:
				OpenSave.import_reference_image_from_path(path)

		elif current_import_option == ImageImportOptions.PALETTE:
			Palettes.import_palette_from_path(path)

		elif current_import_option == ImageImportOptions.BRUSH:
			add_brush()

		elif current_import_option == ImageImportOptions.PATTERN:
			var file_name_ext: String = path.get_file()
			file_name_ext = file_name_replace(file_name_ext, "Patterns")
			var file_name: String = file_name_ext.get_basename()
			image.convert(Image.FORMAT_RGBA8)
			Global.patterns_popup.add(image, file_name)

			# Copy the image file into the "pixelorama/Patterns" directory
			var location := "Patterns".plus_file(file_name_ext)
			var dir = Directory.new()
			dir.copy(path, Global.directory_module.xdg_data_home.plus_file(location))


func _on_ApplyAll_toggled(pressed) -> void:
	is_master = pressed
	# below 4 (and the last) line is needed for correct popup placement
	var old_rect = get_rect()
	disconnect("popup_hide", self, "_on_PreviewDialog_popup_hide")
	hide()
	connect("popup_hide", self, "_on_PreviewDialog_popup_hide")
	for child in Global.control.get_children():
		if child != self and "PreviewDialog" in child.name:
			child.hiding = pressed
			if pressed:
				child.hide()
				synchronize()
			else:
				child.popup_centered()
	popup(old_rect)  # needed for correct popup_order


func synchronize() -> void:
	for child in Global.control.get_children():
		if child != self and "PreviewDialog" in child.name:
			var dialog = child
			#sync modes
			var id = current_import_option
			dialog.import_options.select(id)
			dialog.import_options.emit_signal("item_selected", id)

			#sync properties (if any)
			if (
				id == ImageImportOptions.SPRITESHEET_TAB
				or id == ImageImportOptions.SPRITESHEET_LAYER
			):
				dialog.spritesheet_tab_options.get_node("HorizontalFrames").value = min(
					spritesheet_tab_options.get_node("HorizontalFrames").value, image.get_size().x
				)
				dialog.spritesheet_tab_options.get_node("VerticalFrames").value = min(
					spritesheet_tab_options.get_node("VerticalFrames").value, image.get_size().y
				)
				if id == ImageImportOptions.SPRITESHEET_LAYER:
					dialog.spritesheet_lay_opt.get_node("AtFrameSpinbox").value = (spritesheet_lay_opt.get_node(
						"AtFrameSpinbox"
					).value)

			elif id == ImageImportOptions.NEW_FRAME:
				dialog.new_frame_options.get_node("AtLayerOption").selected = (new_frame_options.get_node(
					"AtLayerOption"
				).selected)

			elif id == ImageImportOptions.REPLACE_CEL:
				dialog.replace_cel_options.get_node("AtLayerOption").selected = (replace_cel_options.get_node(
					"AtLayerOption"
				).selected)
				dialog.replace_cel_options.get_node("AtFrameSpinbox").value = (replace_cel_options.get_node(
					"AtFrameSpinbox"
				).value)

			elif id == ImageImportOptions.NEW_LAYER:
				dialog.new_layer_options.get_node("AtFrameSpinbox").value = (new_layer_options.get_node(
					"AtFrameSpinbox"
				).value)

			elif id == ImageImportOptions.BRUSH:
				var type = new_brush_options.get_node("BrushTypeOption").selected
				dialog.new_brush_options.get_node("BrushTypeOption").select(type)
				dialog.new_brush_options.get_node("BrushTypeOption").emit_signal(
					"item_selected", type
				)


func _on_ImportOption_item_selected(id: int) -> void:
	current_import_option = id
	OpenSave.last_dialog_option = current_import_option
	frame_size_label.visible = false
	spritesheet_tab_options.visible = false
	spritesheet_lay_opt.visible = false
	new_frame_options.visible = false
	replace_cel_options.visible = false
	new_layer_options.visible = false
	new_brush_options.visible = false
	texture_rect.get_child(0).visible = false
	texture_rect.get_child(1).visible = false
	rect_size.x = 550

	if id == ImageImportOptions.SPRITESHEET_TAB:
		frame_size_label.visible = true
		spritesheet_tab_options.visible = true
		texture_rect.get_child(0).visible = true
		texture_rect.get_child(1).visible = true
		rect_size.x = spritesheet_tab_options.rect_size.x

	elif id == ImageImportOptions.SPRITESHEET_LAYER:
		frame_size_label.visible = true
		spritesheet_tab_options.visible = true
		spritesheet_lay_opt.visible = true
		texture_rect.get_child(0).visible = true
		texture_rect.get_child(1).visible = true
		rect_size.x = spritesheet_lay_opt.rect_size.x

	elif id == ImageImportOptions.NEW_FRAME:
		new_frame_options.visible = true
		# Fill the at layer option button:
		var at_layer_option: OptionButton = new_frame_options.get_node("AtLayerOption")
		var layers := Global.current_project.layers.duplicate()
		layers.invert()
		var i := 0
		for l in layers:
			if not l is PixelLayer:
				continue
			at_layer_option.add_item(l.name, l.index)
			at_layer_option.set_item_tooltip(i, l.get_layer_path())
			i += 1
		at_layer_option.selected = at_layer_option.get_item_count() - 1
	elif id == ImageImportOptions.REPLACE_CEL:
		replace_cel_options.visible = true
		# Fill the at layer option button:
		var at_layer_option: OptionButton = replace_cel_options.get_node("AtLayerOption")
		var layers := Global.current_project.layers.duplicate()
		layers.invert()
		var i := 0
		for l in layers:
			if not l is PixelLayer:
				continue
			at_layer_option.add_item(l.name, l.index)
			at_layer_option.set_item_tooltip(i, l.get_layer_path())
			i += 1
		at_layer_option.selected = at_layer_option.get_item_count() - 1
		var at_frame_spinbox: SpinBox = replace_cel_options.get_node("AtFrameSpinbox")
		at_frame_spinbox.max_value = Global.current_project.frames.size()

	elif id == ImageImportOptions.NEW_LAYER:
		new_layer_options.visible = true
		new_layer_options.get_node("AtFrameSpinbox").max_value = Global.current_project.frames.size()

	elif id == ImageImportOptions.BRUSH:
		new_brush_options.visible = true


func _on_HorizontalFrames_value_changed(value: int) -> void:
	spritesheet_horizontal = value
	for child in texture_rect.get_node("HorizLines").get_children():
		child.queue_free()

	spritesheet_frame_value_changed(value, false)


func _on_VerticalFrames_value_changed(value: int) -> void:
	spritesheet_vertical = value
	for child in texture_rect.get_node("VerticalLines").get_children():
		child.queue_free()

	spritesheet_frame_value_changed(value, true)


func spritesheet_frame_value_changed(value: int, vertical: bool) -> void:
	var image_size_y = texture_rect.rect_size.y
	var image_size_x = texture_rect.rect_size.x
	if image.get_size().x > image.get_size().y:
		var scale_ratio = image.get_size().x / image_size_x
		image_size_y = image.get_size().y / scale_ratio
	else:
		var scale_ratio = image.get_size().y / image_size_y
		image_size_x = image.get_size().x / scale_ratio

	var offset_x = (texture_rect.rect_size.x - image_size_x) / 2
	var offset_y = (texture_rect.rect_size.y - image_size_y) / 2

	if value > 1:
		var line_distance
		if vertical:
			line_distance = image_size_y / value
		else:
			line_distance = image_size_x / value

		for i in range(1, value):
			var line_2d := Line2D.new()
			line_2d.width = 1
			line_2d.position = Vector2.ZERO
			if vertical:
				line_2d.add_point(Vector2(offset_x, i * line_distance + offset_y))
				line_2d.add_point(Vector2(image_size_x + offset_x, i * line_distance + offset_y))
				texture_rect.get_node("VerticalLines").add_child(line_2d)
			else:
				line_2d.add_point(Vector2(i * line_distance + offset_x, offset_y))
				line_2d.add_point(Vector2(i * line_distance + offset_x, image_size_y + offset_y))
				texture_rect.get_node("HorizLines").add_child(line_2d)

	var frame_width = floor(image.get_size().x / spritesheet_horizontal)
	var frame_height = floor(image.get_size().y / spritesheet_vertical)
	frame_size_label.text = tr("Frame Size") + ": " + str(frame_width) + "×" + str(frame_height)


func _on_BrushTypeOption_item_selected(index: int) -> void:
	brush_type = index
	new_brush_name.visible = false
	if brush_type == BrushTypes.RANDOM:
		new_brush_name.visible = true


func add_brush() -> void:
	image.convert(Image.FORMAT_RGBA8)
	if brush_type == BrushTypes.FILE:
		var file_name_ext: String = path.get_file()
		file_name_ext = file_name_replace(file_name_ext, "Brushes")
		var file_name: String = file_name_ext.get_basename()

		Brushes.add_file_brush([image], file_name)

		# Copy the image file into the "pixelorama/Brushes" directory
		var location := "Brushes".plus_file(file_name_ext)
		var dir = Directory.new()
		dir.copy(path, Global.directory_module.xdg_data_home.plus_file(location))

	elif brush_type == BrushTypes.PROJECT:
		var file_name: String = path.get_file().get_basename()
		Global.current_project.brushes.append(image)
		Brushes.add_project_brush(image, file_name)

	elif brush_type == BrushTypes.RANDOM:
		var brush_name = new_brush_name.get_node("BrushNameLineEdit").text.to_lower()
		if !brush_name.is_valid_filename():
			return
		var dir := Directory.new()
		dir.open(Global.directory_module.xdg_data_home.plus_file("Brushes"))
		if !dir.dir_exists(brush_name):
			dir.make_dir(brush_name)

		dir.open(Global.directory_module.xdg_data_home.plus_file("Brushes").plus_file(brush_name))
		var random_brushes := []
		dir.list_dir_begin()
		var curr_file := dir.get_next()
		while curr_file != "":
			if curr_file.begins_with("~") and brush_name in curr_file:
				random_brushes.append(curr_file)
			curr_file = dir.get_next()
		dir.list_dir_end()

		var file_ext: String = path.get_file().get_extension()
		var index: int = random_brushes.size() + 1
		var file_name = "~" + brush_name + str(index) + "." + file_ext
		var location := "Brushes".plus_file(brush_name).plus_file(file_name)
		dir.copy(path, Global.directory_module.xdg_data_home.plus_file(location))


# Checks if the file already exists
# If it does, add a number to its name, for example
# "Brush_Name" will become "Brush_Name (2)", "Brush_Name (3)", etc.
func file_name_replace(name: String, folder: String) -> String:
	var i := 1
	var file_ext = name.get_extension()
	var temp_name := name
	var dir := Directory.new()
	dir.open(Global.directory_module.xdg_data_home.plus_file(folder))
	while dir.file_exists(temp_name):
		i += 1
		temp_name = name.get_basename() + " (%s)" % i
		temp_name += "." + file_ext
	name = temp_name
	return name
