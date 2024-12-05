class_name ImportPreviewDialog
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
	PATTERN,
	TILESET
}
enum BrushTypes { FILE, PROJECT, RANDOM }

var path: String
var image: Image
var current_import_option := ImageImportOptions.NEW_TAB
var smart_slice := false
var recycle_last_slice_result := false  # Should we recycle the current sliced_rects
var sliced_rects: RegionUnpacker.RectData
var spritesheet_horizontal := 1
var spritesheet_vertical := 1
var brush_type := BrushTypes.FILE
var opened_once := false
var is_main := false
var hiding := false

## keeps track of which custom export to show when it's import option is selected
## Contains ids as keys and custion import option scenes as values
var custom_importers := {}

## A [TextureRect] containing the preview image
@onready var texture_rect := %TextureRect as TextureRect
@onready var aspect_ratio_container := texture_rect.get_parent() as AspectRatioContainer
## The [OptionButton] containing import options
@onready var import_option_button := %ImportOption as OptionButton
## A [CheckBox] for enabling apply all system.
@onready var apply_all := $VBoxContainer/VBoxContainer/ApplyAll as CheckBox

## Label showing size of original image.
@onready var image_size_label := $VBoxContainer/VBoxContainer/SizeContainer/ImageSizeLabel as Label
## Label for showing size of image after import.
@onready var frame_size_label := $VBoxContainer/VBoxContainer/SizeContainer/FrameSizeLabel as Label
## Container for all types of advanced settings like [member spritesheet_options],
## [member new_brush_options] etc...
@onready var import_options := %ImportOptions as VBoxContainer

# Below are some common settings grouped into categories and are made visible/invisible
# depending on what your import option requires.
## container of spritesheet related import options
@onready var spritesheet_options := %ImportOptions/SpritesheetOptions as VBoxContainer
## container of frame related import options
@onready var at_frame_option := %ImportOptions/AtFrame as HBoxContainer
## container of layer related import options
@onready var at_layer_option := %ImportOptions/AtLayer as GridContainer
## container of brush related import options
@onready var new_brush_options := %ImportOptions/NewBrushOptions as HBoxContainer


func _on_ImportPreviewDialog_about_to_show() -> void:
	if opened_once:
		return
	opened_once = true
	# # order as in ImageImportOptions enum
	import_option_button.add_item("New project")
	import_option_button.add_item("Spritesheet (new project)")
	import_option_button.add_item("Spritesheet (new layer)")
	import_option_button.add_item("New frame")
	import_option_button.add_item("Replace cel")
	import_option_button.add_item("New layer")
	import_option_button.add_item("New reference image")
	import_option_button.add_item("New palette")
	import_option_button.add_item("New brush")
	import_option_button.add_item("New pattern")
	import_option_button.add_item("Tileset")

	# adding custom importers
	for id in custom_importers.keys():
		var scene = custom_importers[id]
		var import_name = OpenSave.custom_import_names.find_key(id)
		scene.set("import_preview_dialog", self)
		import_options.add_child(scene)
		import_option_button.add_item(import_name, id)
	# Select the option that the preview dialog before it had selected
	import_option_button.select(OpenSave.last_dialog_option)
	import_option_button.item_selected.emit(import_option_button.selected)

	var img_texture := ImageTexture.create_from_image(image)
	texture_rect.texture = img_texture
	aspect_ratio_container.ratio = float(image.get_width()) / image.get_height()
	# set max values of spritesheet options
	var h_frames := spritesheet_options.find_child("HorizontalFrames") as SpinBox
	var v_frames := spritesheet_options.find_child("VerticalFrames") as SpinBox
	h_frames.max_value = mini(h_frames.max_value, image.get_size().x)
	v_frames.max_value = mini(v_frames.max_value, image.get_size().y)
	# set labels
	image_size_label.text = (
		tr("Image Size") + ": " + str(image.get_size().x) + "×" + str(image.get_size().y)
	)
	frame_size_label.text = (
		tr("Frame Size") + ": " + str(image.get_size().x) + "×" + str(image.get_size().y)
	)
	if OpenSave.preview_dialogs.size() > 1:
		apply_all.visible = true


func _on_visibility_changed() -> void:
	if visible:
		return
	if hiding:  # if the popup is hiding because of main
		return
	elif is_main:  # if the main dialog is closed then close others too
		for child in get_parent().get_children():
			if child is ImportPreviewDialog:
				OpenSave.preview_dialogs.erase(child)
				child.queue_free()
	else:  # dialogs being closed separately
		OpenSave.preview_dialogs.erase(self)
		queue_free()
	# Call Global.dialog_open() only if it's the only preview dialog opened
	if OpenSave.preview_dialogs.size() != 0:
		return
	Global.dialog_open(false)


func _on_ImportPreviewDialog_confirmed() -> void:
	if is_main:  # if the main dialog is confirmed then confirm others too
		is_main = false
		synchronize()
		for child in get_parent().get_children():
			if child is ImportPreviewDialog:
				child.confirmed.emit()
	else:
		if current_import_option == ImageImportOptions.NEW_TAB:
			OpenSave.open_image_as_new_tab(path, image)

		elif current_import_option == ImageImportOptions.SPRITESHEET_TAB:
			if smart_slice:
				if !recycle_last_slice_result:
					obtain_sliced_data()
				OpenSave.open_image_as_spritesheet_tab_smart(
					path, image, sliced_rects.rects, sliced_rects.frame_size
				)
			else:
				OpenSave.open_image_as_spritesheet_tab(
					path, image, spritesheet_horizontal, spritesheet_vertical
				)

		elif current_import_option == ImageImportOptions.SPRITESHEET_LAYER:
			var frame_index: int = at_frame_option.get_node("AtFrameSpinbox").value - 1
			if smart_slice:
				if !recycle_last_slice_result:
					obtain_sliced_data()
				OpenSave.open_image_as_spritesheet_layer_smart(
					path,
					image,
					path.get_basename().get_file(),
					sliced_rects["rects"],
					frame_index,
					sliced_rects["frame_size"]
				)
			else:
				OpenSave.open_image_as_spritesheet_layer(
					path,
					image,
					path.get_basename().get_file(),
					spritesheet_horizontal,
					spritesheet_vertical,
					frame_index
				)

		elif current_import_option == ImageImportOptions.NEW_FRAME:
			var layer_index: int = at_layer_option.get_node("AtLayerOption").get_selected_id()
			OpenSave.open_image_as_new_frame(image, layer_index)

		elif current_import_option == ImageImportOptions.REPLACE_CEL:
			var layer_index: int = at_layer_option.get_node("AtLayerOption").get_selected_id()
			var frame_index: int = at_frame_option.get_node("AtFrameSpinbox").value - 1
			OpenSave.open_image_at_cel(image, layer_index, frame_index)

		elif current_import_option == ImageImportOptions.NEW_LAYER:
			var frame_index: int = at_frame_option.get_node("AtFrameSpinbox").value - 1
			OpenSave.open_image_as_new_layer(image, path.get_basename().get_file(), frame_index)

		elif current_import_option == ImageImportOptions.NEW_REFERENCE_IMAGE:
			if OS.get_name() == "Web":
				OpenSave.import_reference_image_from_image(image)
			else:
				OpenSave.import_reference_image_from_path(path)

		elif current_import_option == ImageImportOptions.PALETTE:
			Palettes.import_palette_from_path(path, true)

		elif current_import_option == ImageImportOptions.BRUSH:
			add_brush()

		elif current_import_option == ImageImportOptions.PATTERN:
			var file_name_ext: String = path.get_file()
			file_name_ext = file_name_replace(file_name_ext, "Patterns")
			var file_name: String = file_name_ext.get_basename()
			image.convert(Image.FORMAT_RGBA8)
			Global.patterns_popup.add(image, file_name)

			# Copy the image file into the "pixelorama/Patterns" directory
			var location := "Patterns".path_join(file_name_ext)
			var dir := DirAccess.open(path.get_base_dir())
			dir.copy(path, Global.home_data_directory.path_join(location))
		elif current_import_option == ImageImportOptions.TILESET:
			if smart_slice:
				if !recycle_last_slice_result:
					obtain_sliced_data()
				OpenSave.open_image_as_tileset_smart(
					path, image, sliced_rects.rects, sliced_rects.frame_size
				)
			else:
				OpenSave.open_image_as_tileset(
					path, image, spritesheet_horizontal, spritesheet_vertical
				)

		else:
			if current_import_option in custom_importers.keys():
				var importer = custom_importers[current_import_option]
				if importer.has_method("initiate_import"):
					importer.call("initiate_import", path, image)


func _on_ApplyAll_toggled(pressed: bool) -> void:
	is_main = pressed
	# below 4 (and the last) line is needed for correct popup placement
	var old_rect := Rect2i(position, size)
	visibility_changed.disconnect(_on_visibility_changed)
	hide()
	visibility_changed.connect(_on_visibility_changed)
	for child in get_parent().get_children():
		if child != self and child is ImportPreviewDialog:
			child.hiding = pressed
			if pressed:
				child.hide()
				synchronize()
			else:
				child.popup_centered()
	popup(old_rect)  # needed for correct popup_order


func synchronize() -> void:
	var at_frame_spinbox := at_frame_option.get_node("AtFrameSpinbox") as SpinBox
	var at_layer_option_button := at_layer_option.get_node("AtLayerOption") as OptionButton
	for child in get_parent().get_children():
		if child == self or not child is ImportPreviewDialog:
			continue
		var dialog := child as ImportPreviewDialog
		# Sync modes
		var id := current_import_option
		dialog.import_option_button.select(id)
		dialog.import_option_button.item_selected.emit(id)
		# Nodes
		var d_at_frame_spinbox := dialog.at_frame_option.get_node("AtFrameSpinbox") as SpinBox
		var d_at_layer_option_button := (
			dialog.at_layer_option.get_node("AtLayerOption") as OptionButton
		)
		# Sync properties (if any)
		if (
			id == ImageImportOptions.SPRITESHEET_TAB
			or id == ImageImportOptions.SPRITESHEET_LAYER
			or id == ImageImportOptions.TILESET
		):
			var h_frames := spritesheet_options.find_child("HorizontalFrames") as SpinBox
			var v_frames := spritesheet_options.find_child("VerticalFrames") as SpinBox
			var d_h_frames := dialog.spritesheet_options.find_child("HorizontalFrames") as SpinBox
			var d_v_frames := dialog.spritesheet_options.find_child("VerticalFrames") as SpinBox
			d_h_frames.value = mini(h_frames.value, image.get_size().x)
			d_v_frames.value = mini(v_frames.value, image.get_size().y)
			if id == ImageImportOptions.SPRITESHEET_LAYER:
				d_at_frame_spinbox.value = at_frame_spinbox.value

		elif id == ImageImportOptions.NEW_FRAME:
			d_at_layer_option_button.selected = at_layer_option_button.selected

		elif id == ImageImportOptions.REPLACE_CEL:
			d_at_layer_option_button.selected = at_layer_option_button.selected
			d_at_frame_spinbox.value = at_frame_spinbox.value

		elif id == ImageImportOptions.NEW_LAYER:
			d_at_frame_spinbox.value = at_frame_spinbox.value

		elif id == ImageImportOptions.BRUSH:
			var brush_type_option := new_brush_options.get_node("BrushTypeOption") as OptionButton
			var d_brush_type_option := (
				dialog.new_brush_options.get_node("BrushTypeOption") as OptionButton
			)
			var type := brush_type_option.selected
			d_brush_type_option.select(type)
			d_brush_type_option.item_selected.emit(type)


## Reset some options
func _hide_all_options() -> void:
	smart_slice = false
	apply_all.disabled = false
	spritesheet_options.get_node("SmartSliceToggle").button_pressed = false
	at_frame_option.get_node("AtFrameSpinbox").allow_greater = false
	texture_rect.get_child(0).visible = false
	texture_rect.get_child(1).visible = false
	for child in import_options.get_children():
		child.visible = false


func _on_ImportOption_item_selected(id: ImageImportOptions) -> void:
	current_import_option = id
	OpenSave.last_dialog_option = current_import_option
	_hide_all_options()
	import_options.get_parent().visible = true

	if id == ImageImportOptions.SPRITESHEET_TAB or id == ImageImportOptions.TILESET:
		frame_size_label.visible = true
		spritesheet_options.visible = true
		texture_rect.get_child(0).visible = true
		texture_rect.get_child(1).visible = true

	elif id == ImageImportOptions.SPRITESHEET_LAYER:
		frame_size_label.visible = true
		at_frame_option.visible = true
		spritesheet_options.visible = true
		texture_rect.get_child(0).visible = true
		texture_rect.get_child(1).visible = true
		at_frame_option.get_node("AtFrameSpinbox").allow_greater = true

	elif id == ImageImportOptions.NEW_FRAME:
		at_layer_option.visible = true
		# Fill the at layer option button:
		var at_layer_option_button: OptionButton = at_layer_option.get_node("AtLayerOption")
		at_layer_option_button.clear()
		var layers := Global.current_project.layers.duplicate()
		layers.reverse()
		var i := 0
		for l in layers:
			if not l is PixelLayer:
				continue
			at_layer_option_button.add_item(l.name, l.index)
			at_layer_option_button.set_item_tooltip(i, l.get_layer_path())
			i += 1
		at_layer_option_button.selected = at_layer_option_button.get_item_count() - 1

	elif id == ImageImportOptions.REPLACE_CEL:
		at_frame_option.visible = true
		at_layer_option.visible = true
		# Fill the at layer option button:
		var at_layer_option_button: OptionButton = at_layer_option.get_node("AtLayerOption")
		at_layer_option_button.clear()
		var layers := Global.current_project.layers.duplicate()
		layers.reverse()
		var i := 0
		for l in layers:
			if not l is PixelLayer:
				continue
			at_layer_option_button.add_item(l.name, l.index)
			at_layer_option_button.set_item_tooltip(i, l.get_layer_path())
			i += 1
		at_layer_option_button.selected = at_layer_option_button.get_item_count() - 1
		var at_frame_spinbox: SpinBox = at_frame_option.get_node("AtFrameSpinbox")
		at_frame_spinbox.max_value = Global.current_project.frames.size()

	elif id == ImageImportOptions.NEW_LAYER:
		at_frame_option.visible = true
		at_frame_option.get_node("AtFrameSpinbox").max_value = (
			Global.current_project.frames.size()
		)

	elif id == ImageImportOptions.BRUSH:
		new_brush_options.visible = true

	else:
		if id in ImageImportOptions.values():
			import_options.get_parent().visible = false
		else:
			if is_main:  # Disable apply all (for import options added by extension)
				apply_all.button_pressed = false
			apply_all.disabled = true
			if id in custom_importers.keys():
				custom_importers[id].visible = true
	_call_queue_redraw()


func _on_smart_slice_toggled(button_pressed: bool) -> void:
	setup_smart_slice(button_pressed)


func setup_smart_slice(enabled: bool) -> void:
	spritesheet_options.get_node("Manual").visible = !enabled
	spritesheet_options.get_node("Smart").visible = enabled
	if is_main:  # Disable apply all (the algorithm is not fast enough for this)
		apply_all.button_pressed = false
	apply_all.disabled = enabled
	smart_slice = enabled
	if !recycle_last_slice_result and enabled:
		slice_preview()
	_call_queue_redraw()


func obtain_sliced_data() -> void:
	var merge_threshold := spritesheet_options.find_child("Threshold") as ValueSlider
	var merge_dist := spritesheet_options.find_child("MergeDist") as ValueSlider
	var unpak := RegionUnpacker.new(merge_threshold.value, merge_dist.value)
	sliced_rects = unpak.get_used_rects(texture_rect.texture.get_image())


func slice_preview() -> void:
	sliced_rects = null
	obtain_sliced_data()
	recycle_last_slice_result = true
	var frame_size := sliced_rects.frame_size
	frame_size_label.text = tr("Frame Size") + ": " + str(frame_size.x) + "×" + str(frame_size.y)


func _on_threshold_value_changed(_value: float) -> void:
	recycle_last_slice_result = false


func _on_merge_dist_value_changed(_value: float) -> void:
	recycle_last_slice_result = false


func _on_slice_pressed() -> void:
	if !recycle_last_slice_result:
		slice_preview()
	_call_queue_redraw()


func _on_HorizontalFrames_value_changed(value: int) -> void:
	spritesheet_horizontal = value
	spritesheet_frame_value_changed()


func _on_VerticalFrames_value_changed(value: int) -> void:
	spritesheet_vertical = value
	spritesheet_frame_value_changed()


func spritesheet_frame_value_changed() -> void:
	var frame_width := floori(image.get_size().x / spritesheet_horizontal)
	var frame_height := floori(image.get_size().y / spritesheet_vertical)
	frame_size_label.text = tr("Frame Size") + ": " + str(frame_width) + "×" + str(frame_height)
	_call_queue_redraw()


func _on_BrushTypeOption_item_selected(index: BrushTypes) -> void:
	brush_type = index
	new_brush_options.get_node("BrushName").visible = false
	if brush_type == BrushTypes.RANDOM:
		new_brush_options.get_node("BrushName").visible = true


func add_brush() -> void:
	image.convert(Image.FORMAT_RGBA8)
	if brush_type == BrushTypes.FILE:
		var file_name_ext := path.get_file()
		file_name_ext = file_name_replace(file_name_ext, "Brushes")
		var file_name := file_name_ext.get_basename()

		Brushes.add_file_brush([image], file_name)

		# Copy the image file into the "pixelorama/Brushes" directory
		var location := "Brushes".path_join(file_name_ext)
		var dir := DirAccess.open(path.get_base_dir())
		dir.copy(path, Global.home_data_directory.path_join(location))

	elif brush_type == BrushTypes.PROJECT:
		var file_name := path.get_file().get_basename()
		Global.current_project.brushes.append(image)
		Brushes.add_project_brush(image, file_name)

	elif brush_type == BrushTypes.RANDOM:
		var brush_name_edit := new_brush_options.get_node("BrushName/BrushNameLineEdit") as LineEdit
		var brush_name := brush_name_edit.text.to_lower()
		if !brush_name.is_valid_filename():
			return
		var dir := DirAccess.open(Global.home_data_directory.path_join("Brushes"))
		if !dir.dir_exists(brush_name):
			dir.make_dir(brush_name)

		dir = DirAccess.open(Global.home_data_directory.path_join("Brushes").path_join(brush_name))
		var random_brushes := []
		dir.list_dir_begin()
		var curr_file := dir.get_next()
		while curr_file != "":
			if curr_file.begins_with("~") and brush_name in curr_file:
				random_brushes.append(curr_file)
			curr_file = dir.get_next()
		dir.list_dir_end()

		var file_ext := path.get_file().get_extension()
		var index := random_brushes.size() + 1
		var file_name := "~" + brush_name + str(index) + "." + file_ext
		var location := "Brushes".path_join(brush_name).path_join(file_name)
		dir.copy(path, Global.home_data_directory.path_join(location))


## Checks if the file already exists
## If it does, add a number to its name, for example
## "Brush_Name" will become "Brush_Name (2)", "Brush_Name (3)", etc.
func file_name_replace(file_name: String, folder: String) -> String:
	var i := 1
	var file_ext := file_name.get_extension()
	var temp_name := file_name
	while FileAccess.file_exists(Global.home_data_directory.path_join(folder).path_join(temp_name)):
		i += 1
		temp_name = file_name.get_basename() + " (%s)" % i
		temp_name += "." + file_ext
	file_name = temp_name
	return file_name


func _call_queue_redraw() -> void:
	var empty_array: Array[Rect2i] = []
	$"%SmartSlice".show_preview(empty_array)
	$"%RowColumnLines".show_preview(1, 1)
	await get_tree().process_frame
	if (
		current_import_option == ImageImportOptions.SPRITESHEET_TAB
		or current_import_option == ImageImportOptions.SPRITESHEET_LAYER
		or current_import_option == ImageImportOptions.TILESET
	):
		if smart_slice:
			if is_instance_valid(sliced_rects) and not sliced_rects.rects.is_empty():
				$"%SmartSlice".show_preview(sliced_rects.rects)
		else:
			$"%RowColumnLines".show_preview(spritesheet_vertical, spritesheet_horizontal)


func _on_preview_container_size_changed() -> void:
	_call_queue_redraw()
