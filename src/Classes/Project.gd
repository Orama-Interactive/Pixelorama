# gdlint: ignore=max-public-methods
class_name Project
extends RefCounted
## A class for project properties.

signal removed
signal serialized(dict: Dictionary)
signal about_to_deserialize(dict: Dictionary)
signal resized
signal timeline_updated
signal fps_changed

const INDEXED_MODE := Image.FORMAT_MAX + 1

var name := "":
	set(value):
		name = value
		var project_index := Global.projects.find(self)
		if project_index < Global.tabs.tab_count and project_index > -1:
			Global.tabs.set_tab_title(project_index, name)
var size: Vector2i:
	set = _size_changed
var undo_redo := UndoRedo.new()
var tiles: Tiles
var undos := 0  ## The number of times we added undo properties
var can_undo := true
var color_mode: int = Image.FORMAT_RGBA8:
	set(value):
		if color_mode != value:
			color_mode = value
			for cel in get_all_pixel_cels():
				var image := cel.get_image()
				image.is_indexed = is_indexed()
				if image.is_indexed:
					image.resize_indices()
					image.select_palette("", false)
					image.convert_rgb_to_indexed()
		Global.canvas.color_index.queue_redraw()
var fill_color := Color(0)
var has_changed := false:
	set(value):
		has_changed = value
		if value:
			Global.project_data_changed.emit(self)
			Global.tabs.set_tab_title(Global.tabs.current_tab, name + "(*)")
		else:
			Global.tabs.set_tab_title(Global.tabs.current_tab, name)
# frames and layers Arrays should generally only be modified directly when
# opening/creating a project. When modifying the current project, use
# the add/remove/move/swap_frames/layers methods
var frames: Array[Frame] = []
var layers: Array[BaseLayer] = []
var current_frame := 0
var current_layer := 0
var selected_cels := [[0, 0]]  ## Array of Arrays of 2 integers (frame & layer)
## Array that contains the order of the [BaseLayer] indices that are being drawn.
## Takes into account each [BaseCel]'s invidiual z-index. If all z-indexes are 0, then the
## array just contains the indices of the layers in increasing order.
## See [method order_layers].
var ordered_layers: Array[int] = [0]

var animation_tags: Array[AnimationTag] = []:
	set = _animation_tags_changed
var guides: Array[Guide] = []
var brushes: Array[Image] = []
var reference_images: Array[ReferenceImage] = []
var reference_index: int = -1  # The currently selected index ReferenceImage
var vanishing_points := []  ## Array of Vanishing Points
var fps := 6.0:
	set(value):
		fps = value
		fps_changed.emit()
var user_data := ""  ## User defined data, set in the project properties.

var x_symmetry_point: float
var y_symmetry_point: float
var xy_symmetry_point: Vector2
var x_minus_y_symmetry_point: Vector2
var x_symmetry_axis := SymmetryGuide.new()
var y_symmetry_axis := SymmetryGuide.new()
var diagonal_xy_symmetry_axis := SymmetryGuide.new()
var diagonal_x_minus_y_symmetry_axis := SymmetryGuide.new()

var selection_map := SelectionMap.new()
## This is useful for when the selection is outside of the canvas boundaries,
## on the left and/or above (negative coords)
var selection_offset := Vector2i.ZERO:
	set(value):
		selection_offset = value
		Global.canvas.selection.marching_ants_outline.offset = selection_offset
var has_selection := false
var tilesets: Array[TileSetCustom]

## For every camera (currently there are 3)
var cameras_rotation: PackedFloat32Array = [0.0, 0.0, 0.0]
var cameras_zoom: PackedVector2Array = [
	Vector2(0.15, 0.15), Vector2(0.15, 0.15), Vector2(0.15, 0.15)
]
var cameras_offset: PackedVector2Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]

# Export directory path and export file name
var save_path := ""
var export_directory_path := ""
var file_name := "untitled"
var file_format := Export.FileFormat.PNG
var was_exported := false
var export_overwrite := false
var backup_path := ""

var animation_tag_node := preload("res://src/UI/Timeline/AnimationTagUI.tscn")


func _init(_frames: Array[Frame] = [], _name := tr("untitled"), _size := Vector2i(64, 64)) -> void:
	frames = _frames
	name = _name
	size = _size
	tiles = Tiles.new(size)
	selection_map.copy_from(Image.create(size.x, size.y, false, Image.FORMAT_LA8))
	Global.tabs.add_tab(name)
	undo_redo.max_steps = Global.max_undo_steps

	x_symmetry_point = size.x - 1
	y_symmetry_point = size.y - 1
	xy_symmetry_point = Vector2i(size.y, size.x) - Vector2i.ONE
	x_minus_y_symmetry_point = Vector2(maxi(size.x - size.y, 0), maxi(size.y - size.x, 0))
	x_symmetry_axis.type = Guide.Types.HORIZONTAL
	x_symmetry_axis.project = self
	x_symmetry_axis.add_point(Vector2(-19999, y_symmetry_point / 2 + 0.5))
	x_symmetry_axis.add_point(Vector2(19999, y_symmetry_point / 2 + 0.5))
	Global.canvas.add_child(x_symmetry_axis)

	y_symmetry_axis.type = Guide.Types.VERTICAL
	y_symmetry_axis.project = self
	y_symmetry_axis.add_point(Vector2(x_symmetry_point / 2 + 0.5, -19999))
	y_symmetry_axis.add_point(Vector2(x_symmetry_point / 2 + 0.5, 19999))
	Global.canvas.add_child(y_symmetry_axis)

	diagonal_xy_symmetry_axis.type = Guide.Types.XY
	diagonal_xy_symmetry_axis.project = self
	diagonal_xy_symmetry_axis.add_point(Vector2(19999, -19999))
	diagonal_xy_symmetry_axis.add_point(Vector2(-19999, 19999) + xy_symmetry_point + Vector2.ONE)
	Global.canvas.add_child(diagonal_xy_symmetry_axis)

	diagonal_x_minus_y_symmetry_axis.type = Guide.Types.X_MINUS_Y
	diagonal_x_minus_y_symmetry_axis.project = self
	diagonal_x_minus_y_symmetry_axis.add_point(Vector2(-19999, -19999))
	diagonal_x_minus_y_symmetry_axis.add_point(Vector2(19999, 19999) + x_minus_y_symmetry_point)
	Global.canvas.add_child(diagonal_x_minus_y_symmetry_axis)

	if OS.get_name() == "Web":
		export_directory_path = "user://"
	else:
		export_directory_path = Global.config_cache.get_value(
			"data", "current_dir", OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
		)
	Global.project_created.emit(self)


func remove() -> void:
	remove_backup_file()
	undo_redo.free()
	for ri in reference_images:
		ri.queue_free()
	if self == Global.current_project:
		# If the project is not current_project then the points need not be removed
		for point_idx in vanishing_points.size():
			var editor = Global.perspective_editor
			for c in editor.vanishing_point_container.get_children():
				c.queue_free()
	for guide in guides:
		guide.queue_free()
	for frame in frames:
		for l in layers.size():
			var cel: BaseCel = frame.cels[l]
			cel.on_remove()
	# Prevents memory leak (due to the layers' project reference stopping ref counting from freeing)
	layers.clear()
	Global.projects.erase(self)
	removed.emit()


func remove_backup_file() -> void:
	if not backup_path.is_empty():
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)


func commit_undo() -> void:
	if not can_undo:
		return
	if Global.canvas.selection.is_moving_content:
		Global.canvas.selection.transform_content_cancel()
	else:
		undo_redo.undo()


func commit_redo() -> void:
	if not can_undo:
		return
	Global.control.redone = true
	undo_redo.redo()
	Global.control.redone = false


func new_empty_frame() -> Frame:
	var frame := Frame.new()
	var bottom_layer := true
	for l in layers:  # Create as many cels as there are layers
		var cel := l.new_empty_cel()
		if cel is PixelCel and bottom_layer and fill_color.a > 0:
			cel.image.fill(fill_color)
		frame.cels.append(cel)
		bottom_layer = false
	return frame


## Returns a new [Image] of size [member size] and format [method get_image_format].
func new_empty_image() -> Image:
	return Image.create(size.x, size.y, false, get_image_format())


## Returns the currently selected [BaseCel].
func get_current_cel() -> BaseCel:
	return frames[current_frame].cels[current_layer]


func get_image_format() -> Image.Format:
	if color_mode == INDEXED_MODE:
		return Image.FORMAT_RGBA8
	return color_mode


func is_indexed() -> bool:
	return color_mode == INDEXED_MODE


func selection_map_changed() -> void:
	var image_texture: ImageTexture
	has_selection = !selection_map.is_invisible()
	if has_selection:
		image_texture = ImageTexture.create_from_image(selection_map)
	Global.canvas.selection.marching_ants_outline.texture = image_texture
	Global.top_menu_container.edit_menu.set_item_disabled(Global.EditMenu.NEW_BRUSH, !has_selection)
	Global.top_menu_container.image_menu.set_item_disabled(
		Global.ImageMenu.CROP_TO_SELECTION, !has_selection
	)


func change_project() -> void:
	Global.animation_timeline.project_changed()
	animation_tags = animation_tags
	# Change the project brushes
	Brushes.clear_project_brush()
	for brush in brushes:
		Brushes.add_project_brush(brush)
	Global.transparent_checker.update_rect()
	Global.cursor_position_label.text = "[%s×%s]" % [size.x, size.y]
	Global.get_window().title = "%s - Pixelorama %s" % [name, Global.current_version]
	if has_changed:
		Global.get_window().title = Global.get_window().title + "(*)"
	selection_map_changed()


func serialize() -> Dictionary:
	var layer_data := []
	for layer in layers:
		layer_data.append(layer.serialize())
		layer_data[-1]["metadata"] = _serialize_metadata(layer)
	var tag_data := []
	for tag in animation_tags:
		tag_data.append(tag.serialize())
	var guide_data := []
	for guide in guides:
		if guide is SymmetryGuide:
			continue
		if !is_instance_valid(guide):
			continue
		var coords := guide.points[0].x
		if guide.type == Guide.Types.HORIZONTAL:
			coords = guide.points[0].y
		guide_data.append({"type": guide.type, "pos": coords})

	var frame_data := []
	for frame in frames:
		var cel_data := []
		for cel in frame.cels:
			cel_data.append(cel.serialize())
			cel_data[-1]["metadata"] = _serialize_metadata(cel)

		var current_frame_data := {
			"cels": cel_data, "duration": frame.duration, "metadata": _serialize_metadata(frame)
		}
		if not frame.user_data.is_empty():
			current_frame_data["user_data"] = frame.user_data
		frame_data.append(current_frame_data)
	var brush_data := []
	for brush in brushes:
		brush_data.append({"size_x": brush.get_size().x, "size_y": brush.get_size().y})

	var reference_image_data := []
	for reference_image in reference_images:
		reference_image_data.append(reference_image.serialize())
	var tileset_data := []
	for tileset in tilesets:
		tileset_data.append(tileset.serialize())

	var metadata := _serialize_metadata(self)

	var project_data := {
		"pixelorama_version": Global.current_version,
		"pxo_version": ProjectSettings.get_setting("application/config/Pxo_Version"),
		"size_x": size.x,
		"size_y": size.y,
		"color_mode": color_mode,
		"tile_mode_x_basis_x": tiles.x_basis.x,
		"tile_mode_x_basis_y": tiles.x_basis.y,
		"tile_mode_y_basis_x": tiles.y_basis.x,
		"tile_mode_y_basis_y": tiles.y_basis.y,
		"layers": layer_data,
		"tags": tag_data,
		"guides": guide_data,
		"symmetry_points": [x_symmetry_point, y_symmetry_point],
		"frames": frame_data,
		"brushes": brush_data,
		"reference_images": reference_image_data,
		"tilesets": tileset_data,
		"vanishing_points": vanishing_points,
		"export_file_name": file_name,
		"export_file_format": file_format,
		"fps": fps,
		"user_data": user_data,
		"metadata": metadata
	}

	serialized.emit(project_data)
	return project_data


func deserialize(dict: Dictionary, zip_reader: ZIPReader = null, file: FileAccess = null) -> void:
	about_to_deserialize.emit(dict)
	var pxo_version = dict.get(
		"pxo_version", ProjectSettings.get_setting("application/config/Pxo_Version")
	)
	if dict.has("size_x") and dict.has("size_y"):
		size.x = dict.size_x
		size.y = dict.size_y
		tiles.tile_size = size
		selection_map.crop(size.x, size.y)
	color_mode = dict.get("color_mode", color_mode)
	if dict.has("tile_mode_x_basis_x") and dict.has("tile_mode_x_basis_y"):
		tiles.x_basis.x = dict.tile_mode_x_basis_x
		tiles.x_basis.y = dict.tile_mode_x_basis_y
	if dict.has("tile_mode_y_basis_x") and dict.has("tile_mode_y_basis_y"):
		tiles.y_basis.x = dict.tile_mode_y_basis_x
		tiles.y_basis.y = dict.tile_mode_y_basis_y
	if dict.has("tilesets"):
		for saved_tileset in dict["tilesets"]:
			var tile_size = str_to_var("Vector2i" + saved_tileset.get("tile_size"))
			var tileset := TileSetCustom.new(tile_size, "", false)
			tileset.deserialize(saved_tileset)
			tilesets.append(tileset)
	if dict.has("frames") and dict.has("layers"):
		var audio_layers := 0
		for saved_layer in dict.layers:
			match int(saved_layer.get("type", Global.LayerTypes.PIXEL)):
				Global.LayerTypes.PIXEL:
					layers.append(PixelLayer.new(self))
				Global.LayerTypes.GROUP:
					layers.append(GroupLayer.new(self))
				Global.LayerTypes.THREE_D:
					layers.append(Layer3D.new(self))
				Global.LayerTypes.TILEMAP:
					layers.append(LayerTileMap.new(self, null))
				Global.LayerTypes.AUDIO:
					var layer := AudioLayer.new(self)
					var audio_path := "audio/%s" % audio_layers
					if zip_reader.file_exists(audio_path):
						var audio_data := zip_reader.read_file(audio_path)
						var stream: AudioStream
						if saved_layer.get("audio_type", "") == "AudioStreamMP3":
							stream = AudioStreamMP3.new()
							stream.data = audio_data
						layer.audio = stream
					layers.append(layer)
					audio_layers += 1

		var frame_i := 0
		for frame in dict.frames:
			var cels: Array[BaseCel] = []
			var cel_i := 0
			for cel in frame.cels:
				var layer := layers[cel_i]
				match layer.get_layer_type():
					Global.LayerTypes.PIXEL:
						var image := _load_image_from_pxo(frame_i, cel_i, zip_reader, file)
						cels.append(PixelCel.new(image))
					Global.LayerTypes.GROUP:
						cels.append(GroupCel.new())
					Global.LayerTypes.THREE_D:
						if is_instance_valid(file):  # For pxo files saved in 0.x
							# Don't do anything with it, just read it so that the file can move on
							file.get_buffer(size.x * size.y * 4)
						cels.append(Cel3D.new(size, true))
					Global.LayerTypes.TILEMAP:
						var image := _load_image_from_pxo(frame_i, cel_i, zip_reader, file)
						var tileset_index = dict.layers[cel_i].tileset_index
						var tileset := tilesets[tileset_index]
						var new_cel := CelTileMap.new(tileset, image)
						cels.append(new_cel)
					Global.LayerTypes.AUDIO:
						cels.append(AudioCel.new())
				cel["pxo_version"] = pxo_version
				cels[cel_i].deserialize(cel)
				_deserialize_metadata(cels[cel_i], cel)
				cel_i += 1
			var duration := 1.0
			if frame.has("duration"):
				duration = frame.duration
			elif dict.has("frame_duration"):
				duration = dict.frame_duration[frame_i]

			var frame_class := Frame.new(cels, duration)
			frame_class.user_data = frame.get("user_data", "")
			_deserialize_metadata(frame_class, frame)
			frames.append(frame_class)
			frame_i += 1

		# Parent references to other layers are created when deserializing
		# a layer, so loop again after creating them:
		for layer_i in dict.layers.size():
			layers[layer_i].index = layer_i
			var layer_dict: Dictionary = dict.layers[layer_i]
			# Ensure that loaded pxo files from v1.0-v1.0.3 have the correct
			# blend mode, after the addition of the Erase mode in v1.0.4.
			if pxo_version < 4 and layer_dict.has("blend_mode"):
				var blend_mode: int = layer_dict.get("blend_mode")
				if blend_mode >= BaseLayer.BlendModes.ERASE:
					blend_mode += 1
				layer_dict["blend_mode"] = blend_mode
			layers[layer_i].deserialize(layer_dict)
			_deserialize_metadata(layers[layer_i], dict.layers[layer_i])
	if dict.has("tags"):
		for tag in dict.tags:
			var new_tag := AnimationTag.new(tag.name, Color(tag.color), tag.from, tag.to)
			new_tag.user_data = tag.get("user_data", "")
			animation_tags.append(new_tag)
		animation_tags = animation_tags
	if dict.has("guides"):
		for g in dict.guides:
			var guide := Guide.new()
			guide.type = g.type
			if guide.type == Guide.Types.HORIZONTAL:
				guide.add_point(Vector2(-99999, g.pos))
				guide.add_point(Vector2(99999, g.pos))
			else:
				guide.add_point(Vector2(g.pos, -99999))
				guide.add_point(Vector2(g.pos, 99999))
			guide.has_focus = false
			guide.project = self
			Global.canvas.add_child(guide)
	if dict.has("reference_images"):
		for g in dict.reference_images:
			var ri := ReferenceImage.new()
			ri.project = self
			ri.deserialize(g)
			Global.canvas.reference_image_container.add_child(ri)
	if dict.has("vanishing_points"):
		vanishing_points = dict.vanishing_points
		Global.perspective_editor.queue_redraw()
	if dict.has("symmetry_points"):
		x_symmetry_point = dict.symmetry_points[0]
		y_symmetry_point = dict.symmetry_points[1]
		for point in x_symmetry_axis.points.size():
			x_symmetry_axis.points[point].y = floorf(y_symmetry_point / 2 + 1)
		for point in y_symmetry_axis.points.size():
			y_symmetry_axis.points[point].x = floorf(x_symmetry_point / 2 + 1)
	file_name = dict.get("export_file_name", file_name)
	file_format = dict.get("export_file_format", file_name)
	fps = dict.get("fps", file_name)
	user_data = dict.get("user_data", user_data)
	_deserialize_metadata(self, dict)
	order_layers()


func _serialize_metadata(object: Object) -> Dictionary:
	var metadata := {}
	for meta in object.get_meta_list():
		metadata[meta] = object.get_meta(meta)
	return metadata


func _deserialize_metadata(object: Object, dict: Dictionary) -> void:
	if not dict.has("metadata"):
		return
	var metadata: Dictionary = dict["metadata"]
	for meta in metadata.keys():
		object.set_meta(meta, metadata[meta])


## Called by [method deserialize], this method loads an image at
## a given [param frame_i] frame index and a [param cel_i] cel index from a pxo file,
## and returns it as an [ImageExtended].
## If the pxo file is saved with Pixelorama version 1.0 and on,
## the [param zip_reader] is used to load the image. Otherwise, [param file] is used.
func _load_image_from_pxo(
	frame_i: int, cel_i: int, zip_reader: ZIPReader, file: FileAccess
) -> ImageExtended:
	var image: Image
	var indices_data := PackedByteArray()
	if is_instance_valid(zip_reader):  # For pxo files saved in 1.0+
		var path := "image_data/frames/%s/layer_%s" % [frame_i + 1, cel_i + 1]
		var image_data := zip_reader.read_file(path)
		image = Image.create_from_data(size.x, size.y, false, get_image_format(), image_data)
		var indices_path := "image_data/frames/%s/indices_layer_%s" % [frame_i + 1, cel_i + 1]
		if zip_reader.file_exists(indices_path):
			indices_data = zip_reader.read_file(indices_path)
	elif is_instance_valid(file):  # For pxo files saved in 0.x
		var buffer := file.get_buffer(size.x * size.y * 4)
		image = Image.create_from_data(size.x, size.y, false, get_image_format(), buffer)
	var pixelorama_image := ImageExtended.new()
	pixelorama_image.is_indexed = is_indexed()
	if not indices_data.is_empty() and is_indexed():
		pixelorama_image.indices_image = Image.create_from_data(
			size.x, size.y, false, Image.FORMAT_R8, indices_data
		)
	pixelorama_image.copy_from(image)
	pixelorama_image.select_palette("", true)
	return pixelorama_image


func _size_changed(value: Vector2i) -> void:
	if not is_instance_valid(tiles):
		size = value
		return
	if size.x != 0:
		tiles.x_basis = tiles.x_basis * value.x / size.x
	else:
		tiles.x_basis = Vector2i(value.x, 0)
	if size.y != 0:
		tiles.y_basis = tiles.y_basis * value.y / size.y
	else:
		tiles.y_basis = Vector2i(0, value.y)
	tiles.tile_size = value
	size = value
	Global.canvas.crop_rect.reset()
	resized.emit()


func change_cel(new_frame: int, new_layer := -1) -> void:
	if new_frame < 0:
		new_frame = current_frame
	if new_layer < 0:
		new_layer = current_layer
	Global.canvas.selection.transform_content_confirm()
	# Unpress all buttons
	for i in frames.size():
		var frame_button: BaseButton = Global.frame_hbox.get_child(i)
		frame_button.button_pressed = false  # Unpress all frame buttons
		for cel_hbox in Global.cel_vbox.get_children():
			if i < cel_hbox.get_child_count():
				cel_hbox.get_child(i).button_pressed = false  # Unpress all cel buttons

	for layer_button in Global.layer_vbox.get_children():
		layer_button.button_pressed = false  # Unpress all layer buttons

	if selected_cels.is_empty():
		selected_cels.append([new_frame, new_layer])
	for cel in selected_cels:  # Press selected buttons
		var frame: int = cel[0]
		var layer: int = cel[1]
		if frame < Global.frame_hbox.get_child_count():
			var frame_button: BaseButton = Global.frame_hbox.get_child(frame)
			frame_button.button_pressed = true  # Press selected frame buttons

		var layer_vbox_child_count: int = Global.layer_vbox.get_child_count()
		if layer < layer_vbox_child_count:
			var layer_button = Global.layer_vbox.get_child(layer_vbox_child_count - 1 - layer)
			layer_button.button_pressed = true  # Press selected layer buttons

		var cel_vbox_child_count: int = Global.cel_vbox.get_child_count()
		if layer < cel_vbox_child_count:
			var cel_hbox: Container = Global.cel_vbox.get_child(cel_vbox_child_count - 1 - layer)
			if frame < cel_hbox.get_child_count():
				var cel_button: BaseButton = cel_hbox.get_child(frame)
				cel_button.button_pressed = true  # Press selected cel buttons

	if new_frame != current_frame:  # If the frame has changed
		current_frame = new_frame

	if new_layer != current_layer:  # If the layer has changed
		current_layer = new_layer

	order_layers()
	Global.transparent_checker.update_rect()
	Global.cel_switched.emit()
	if get_current_cel() is Cel3D:
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	Global.canvas.update_all_layers = true
	Global.canvas.queue_redraw()


func _animation_tags_changed(value: Array[AnimationTag]) -> void:
	animation_tags = value
	for child in Global.tag_container.get_children():
		child.queue_free()

	for tag in animation_tags:
		var tag_c := animation_tag_node.instantiate()
		tag_c.tag = tag
		Global.tag_container.add_child(tag_c)
		var tag_position := Global.tag_container.get_child_count() - 1
		Global.tag_container.move_child(tag_c, tag_position)

	_set_timeline_first_and_last_frames()


func _set_timeline_first_and_last_frames() -> void:
	# This is useful in case tags get modified DURING the animation is playing
	# otherwise, this code is useless in this context, since these values are being set
	# when the play buttons get pressed anyway
	Global.animation_timeline.first_frame = 0
	Global.animation_timeline.last_frame = frames.size() - 1
	if Global.play_only_tags:
		for tag in animation_tags:
			if current_frame + 1 >= tag.from && current_frame + 1 <= tag.to:
				Global.animation_timeline.first_frame = tag.from - 1
				Global.animation_timeline.last_frame = mini(frames.size() - 1, tag.to - 1)


func is_empty() -> bool:
	return (
		frames.size() == 1
		and layers.size() == 1
		and layers[0] is PixelLayer
		and frames[0].cels[0].image.is_invisible()
		and animation_tags.size() == 0
	)


func can_pixel_get_drawn(pixel: Vector2i, image := selection_map) -> bool:
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= size.x or pixel.y >= size.y:
		return false

	if tiles.mode != Tiles.MODE.NONE and !tiles.has_point(pixel):
		return false

	if has_selection:
		return image.is_pixel_selected(pixel)
	else:
		return true


## Loops through all of the cels until it finds a drawable (non-[GroupCel]) [BaseCel]
## in the specified [param frame] and returns it. If no drawable cel is found,
## meaning that all of the cels are [GroupCel]s, the method returns null.
## If no [param frame] is specified, the method will use the current frame.
func find_first_drawable_cel(frame := frames[current_frame]) -> BaseCel:
	var result: BaseCel
	var cel := frame.cels[0]
	var i := 0
	while (cel is GroupCel or cel is AudioCel) and i < layers.size():
		cel = frame.cels[i]
		i += 1
	if cel is not GroupCel and cel is not AudioCel:
		result = cel
	return result


## Returns an [Array] of type [PixelCel] containing all of the pixel cels of the project.
func get_all_pixel_cels() -> Array[PixelCel]:
	var cels: Array[PixelCel]
	for frame in frames:
		for cel in frame.cels:
			if cel is PixelCel:
				cels.append(cel)
	return cels


func get_all_audio_layers(only_valid_streams := true) -> Array[AudioLayer]:
	var audio_layers: Array[AudioLayer]
	for layer in layers:
		if layer is AudioLayer:
			if only_valid_streams:
				if is_instance_valid(layer.audio):
					audio_layers.append(layer)
			else:
				audio_layers.append(layer)
	return audio_layers


## Reads data from [param cels] and appends them to [param data],
## to be used for the undo/redo system.
## It adds data such as the images of [PixelCel]s,
## and calls [method CelTileMap.serialize_undo_data] for [CelTileMap]s.
func serialize_cel_undo_data(cels: Array[BaseCel], data: Dictionary) -> void:
	var cels_to_serialize := cels
	if not TileSetPanel.placing_tiles:
		cels_to_serialize = find_same_tileset_tilemap_cels(cels)
	for cel in cels_to_serialize:
		if not cel is PixelCel:
			continue
		var image := (cel as PixelCel).get_image()
		image.add_data_to_dictionary(data)
		if cel is CelTileMap:
			data[cel] = (cel as CelTileMap).serialize_undo_data()


## Loads data from [param redo_data] and param [undo_data],
## to be used for the undo/redo system.
## It calls [method Global.undo_redo_compress_images], and
## [method CelTileMap.deserialize_undo_data] for [CelTileMap]s.
func deserialize_cel_undo_data(redo_data: Dictionary, undo_data: Dictionary) -> void:
	Global.undo_redo_compress_images(redo_data, undo_data, self)
	for cel in redo_data:
		if cel is CelTileMap:
			(cel as CelTileMap).deserialize_undo_data(redo_data[cel], undo_redo, false)
	for cel in undo_data:
		if cel is CelTileMap:
			(cel as CelTileMap).deserialize_undo_data(undo_data[cel], undo_redo, true)


## Returns all [BaseCel]s in [param cels], and for every [CelTileMap],
## this methods finds all other [CelTileMap]s that share the same [TileSetCustom],
## and appends them in the array that is being returned by this method.
func find_same_tileset_tilemap_cels(cels: Array[BaseCel]) -> Array[BaseCel]:
	var tilemap_cels: Array[BaseCel]
	var current_tilesets: Array[TileSetCustom]
	for cel in cels:
		tilemap_cels.append(cel)
		if cel is not CelTileMap:
			continue
		current_tilesets.append((cel as CelTileMap).tileset)
	for cel in get_all_pixel_cels():
		if cel is not CelTileMap:
			continue
		if (cel as CelTileMap).tileset in current_tilesets:
			if cel not in cels:
				tilemap_cels.append(cel)
	return tilemap_cels


## Re-order layers to take each cel's z-index into account. If all z-indexes are 0,
## then the order of drawing is the same as the order of the layers itself.
func order_layers(frame_index := current_frame) -> void:
	ordered_layers = []
	for i in layers.size():
		ordered_layers.append(i)
	ordered_layers.sort_custom(_z_index_sort.bind(frame_index))


## Used as a [Callable] for [method Array.sort_custom] to sort layers
## while taking each cel's z-index into account.
func _z_index_sort(a: int, b: int, frame_index: int) -> bool:
	var z_index_a := frames[frame_index].cels[a].z_index
	var z_index_b := frames[frame_index].cels[b].z_index
	var layer_index_a := layers[a].index + z_index_a
	var layer_index_b := layers[b].index + z_index_b
	if layer_index_a < layer_index_b:
		return true
	if layer_index_a == layer_index_b and z_index_a < z_index_b:
		return true
	return false


# Timeline modifications
# Modifying layers or frames Arrays on the current project should generally only be done
# through these methods.
# These allow you to add/remove/move/swap frames/layers/cels. It updates the Animation Timeline
# UI, and updates indices. These are designed to be reversible, meaning that to undo an add, you
# use remove, and vice versa. To undo a move or swap, use move or swap with the parameters swapped.


# indices should be in ascending order
func add_frames(new_frames: Array, indices: PackedInt32Array) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	for i in new_frames.size():
		# For each linked cel in the frame, update its layer's cel_link_sets
		for l in layers.size():
			var cel: BaseCel = new_frames[i].cels[l]
			if cel.link_set != null:
				if not layers[l].cel_link_sets.has(cel.link_set):
					layers[l].cel_link_sets.append(cel.link_set)
				cel.link_set["cels"].append(cel)
		# Add frame
		frames.insert(indices[i], new_frames[i])
		Global.animation_timeline.project_frame_added(indices[i])
	_update_frame_ui()


func remove_frames(indices: PackedInt32Array) -> void:  # indices should be in ascending order
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	for i in indices.size():
		# With each removed index, future indices need to be lowered, so subtract by i
		# For each linked cel in the frame, update its layer's cel_link_sets
		for l in layers.size():
			var cel := frames[indices[i] - i].cels[l]
			cel.on_remove()
			if cel.link_set != null:
				cel.link_set["cels"].erase(cel)
				if cel.link_set["cels"].is_empty():
					layers[l].cel_link_sets.erase(cel.link_set)
		# Remove frame
		frames.remove_at(indices[i] - i)
		Global.animation_timeline.project_frame_removed(indices[i] - i)
	_update_frame_ui()


# from_indices and to_indicies should be in ascending order
func move_frames(from_indices: PackedInt32Array, to_indices: PackedInt32Array) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	var removed_frames := []
	for i in from_indices.size():
		# With each removed index, future indices need to be lowered, so subtract by i
		removed_frames.append(frames.pop_at(from_indices[i] - i))
		Global.animation_timeline.project_frame_removed(from_indices[i] - i)
	for i in to_indices.size():
		frames.insert(to_indices[i], removed_frames[i])
		Global.animation_timeline.project_frame_added(to_indices[i])
	_update_frame_ui()


func swap_frame(a_index: int, b_index: int) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	var temp := frames[a_index]
	frames[a_index] = frames[b_index]
	frames[b_index] = temp
	Global.animation_timeline.project_frame_removed(a_index)
	Global.animation_timeline.project_frame_added(a_index)
	Global.animation_timeline.project_frame_removed(b_index)
	Global.animation_timeline.project_frame_added(b_index)
	_set_timeline_first_and_last_frames()


func reverse_frames(frame_indices: PackedInt32Array) -> void:
	Global.canvas.selection.transform_content_confirm()
	for i in frame_indices.size() / 2:
		var index := frame_indices[i]
		var reverse_index := frame_indices[-i - 1]
		var temp := frames[index]
		frames[index] = frames[reverse_index]
		frames[reverse_index] = temp
		Global.animation_timeline.project_frame_removed(index)
		Global.animation_timeline.project_frame_added(index)
		Global.animation_timeline.project_frame_removed(reverse_index)
		Global.animation_timeline.project_frame_added(reverse_index)
	_set_timeline_first_and_last_frames()
	change_cel(-1)


## [param cels] is 2d Array of [BaseCel]s
func add_layers(new_layers: Array, indices: PackedInt32Array, cels: Array) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	for i in indices.size():
		layers.insert(indices[i], new_layers[i])
		for f in frames.size():
			frames[f].cels.insert(indices[i], cels[i][f])
		new_layers[i].project = self
		Global.animation_timeline.project_layer_added(indices[i])
	_update_layer_ui()


func remove_layers(indices: PackedInt32Array) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	for i in indices.size():
		# With each removed index, future indices need to be lowered, so subtract by i
		layers.remove_at(indices[i] - i)
		for frame in frames:
			frame.cels[indices[i] - i].on_remove()
			frame.cels.remove_at(indices[i] - i)
		Global.animation_timeline.project_layer_removed(indices[i] - i)
	_update_layer_ui()


# from_indices and to_indicies should be in ascending order
func move_layers(
	from_indices: PackedInt32Array, to_indices: PackedInt32Array, to_parents: Array
) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	var removed_layers := []
	var removed_cels := []  # 2D array of cels (an array for each layer removed)

	for i in from_indices.size():
		# With each removed index, future indices need to be lowered, so subtract by i
		removed_layers.append(layers.pop_at(from_indices[i] - i))
		removed_layers[i].parent = to_parents[i]  # parents must be set before UI created in next loop
		removed_cels.append([])
		for frame in frames:
			removed_cels[i].append(frame.cels.pop_at(from_indices[i] - i))
		Global.animation_timeline.project_layer_removed(from_indices[i] - i)
	for i in to_indices.size():
		layers.insert(to_indices[i], removed_layers[i])
		for f in frames.size():
			frames[f].cels.insert(to_indices[i], removed_cels[i][f])
		Global.animation_timeline.project_layer_added(to_indices[i])
	_update_layer_ui()


# "a" and "b" should both contain "from", "to", and "to_parents" arrays.
# (Using dictionaries because there seems to be a limit of 5 arguments for do/undo method calls)
func swap_layers(a: Dictionary, b: Dictionary) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	var a_layers := []
	var b_layers := []
	var a_cels := []  # 2D array of cels (an array for each layer removed)
	var b_cels := []  # 2D array of cels (an array for each layer removed)
	for i in a.from.size():
		a_layers.append(layers.pop_at(a.from[i] - i))
		Global.animation_timeline.project_layer_removed(a.from[i] - i)
		a_layers[i].parent = a.to_parents[i]  # All parents must be set early, before creating buttons
		a_cels.append([])
		for frame in frames:
			a_cels[i].append(frame.cels.pop_at(a.from[i] - i))
	for i in b.from.size():
		var index = (b.from[i] - i) if a.from[0] > b.from[0] else (b.from[i] - i - a.from.size())
		b_layers.append(layers.pop_at(index))
		Global.animation_timeline.project_layer_removed(index)
		b_layers[i].parent = b.to_parents[i]  # All parents must be set early, before creating buttons
		b_cels.append([])
		for frame in frames:
			b_cels[i].append(frame.cels.pop_at(index))

	for i in a_layers.size():
		var index = a.to[i] if a.to[0] < b.to[0] else (a.to[i] - b.to.size())
		layers.insert(index, a_layers[i])
		for f in frames.size():
			frames[f].cels.insert(index, a_cels[i][f])
		Global.animation_timeline.project_layer_added(index)
	for i in b_layers.size():
		layers.insert(b.to[i], b_layers[i])
		for f in frames.size():
			frames[f].cels.insert(b.to[i], b_cels[i][f])
		Global.animation_timeline.project_layer_added(b.to[i])
	_update_layer_ui()


## Moves multiple cels between different frames, but on the same layer.
## TODO: Perhaps figure out a way to optimize this. Right now it copies all of the cels of
## a layer into a temporary array, sorts it and then copies it into each frame's `cels` array
## on that layer. This was done in order to replicate the code from [method move_frames].
## TODO: Make a method like this, but for moving cels between different layers, on the same frame.
func move_cels_same_layer(
	from_indices: PackedInt32Array, to_indices: PackedInt32Array, layer: int
) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	var cels: Array[BaseCel] = []
	for frame in frames:
		cels.append(frame.cels[layer])
	var removed_cels: Array[BaseCel] = []
	for i in from_indices.size():
		# With each removed index, future indices need to be lowered, so subtract by i
		removed_cels.append(cels.pop_at(from_indices[i] - i))
	for i in to_indices.size():
		cels.insert(to_indices[i], removed_cels[i])
	for i in frames.size():
		var new_cel := cels[i]
		frames[i].cels[layer] = new_cel

	for i in from_indices.size():
		# With each removed index, future indices need to be lowered, so subtract by i
		Global.animation_timeline.project_cel_removed(from_indices[i] - i, layer)
	for i in to_indices.size():
		Global.animation_timeline.project_cel_added(to_indices[i], layer)

	# Update the cel buttons for this layer:
	var cel_hbox: HBoxContainer = Global.cel_vbox.get_child(layers.size() - 1 - layer)
	for f in frames.size():
		cel_hbox.get_child(f).frame = f
		cel_hbox.get_child(f).button_setup()


func swap_cel(a_frame: int, a_layer: int, b_frame: int, b_layer: int) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	var temp := frames[a_frame].cels[a_layer]
	frames[a_frame].cels[a_layer] = frames[b_frame].cels[b_layer]
	frames[b_frame].cels[b_layer] = temp
	Global.animation_timeline.project_cel_removed(a_frame, a_layer)
	Global.animation_timeline.project_cel_added(a_frame, a_layer)
	Global.animation_timeline.project_cel_removed(b_frame, b_layer)
	Global.animation_timeline.project_cel_added(b_frame, b_layer)


func _update_frame_ui() -> void:
	for f in frames.size():  # Update the frames and frame buttons
		Global.frame_hbox.get_child(f).frame = f
		Global.frame_hbox.get_child(f).text = str(f + 1)

	for l in layers.size():  # Update the cel buttons
		var cel_hbox: HBoxContainer = Global.cel_vbox.get_child(layers.size() - 1 - l)
		for f in frames.size():
			cel_hbox.get_child(f).frame = f
			cel_hbox.get_child(f).button_setup()
	_set_timeline_first_and_last_frames()
	timeline_updated.emit()


## Update the layer indices and layer/cel buttons
func _update_layer_ui() -> void:
	for l in layers.size():
		layers[l].index = l
		Global.layer_vbox.get_child(layers.size() - 1 - l).layer_index = l
		var cel_hbox: HBoxContainer = Global.cel_vbox.get_child(layers.size() - 1 - l)
		for f in frames.size():
			cel_hbox.get_child(f).layer = l
			cel_hbox.get_child(f).button_setup()
	timeline_updated.emit()


## Change the current reference image
func set_reference_image_index(new_index: int) -> void:
	reference_index = clamp(-1, new_index, reference_images.size() - 1)
	Global.canvas.reference_image_container.update_index(reference_index)


## Returns the reference image based on reference_index
func get_current_reference_image() -> ReferenceImage:
	return get_reference_image(reference_index)


## Returns the reference image based on the index or null if index < 0
func get_reference_image(index: int) -> ReferenceImage:
	if index < 0 or index > reference_images.size() - 1:
		return null
	return reference_images[index]


## Reorders the position of the reference image in the tree / reference_images array
func reorder_reference_image(from: int, to: int) -> void:
	var ri: ReferenceImage = reference_images.pop_at(from)
	reference_images.insert(to, ri)
	Global.canvas.reference_image_container.move_child(ri, to)


## Adds a new [param tileset] to [member tilesets].
func add_tileset(tileset: TileSetCustom) -> void:
	tilesets.append(tileset)


## Loops through all cels in [param cel_dictionary], and for [CelTileMap]s,
## it calls [method CelTileMap.update_tilemap].
func update_tilemaps(
	cel_dictionary: Dictionary, tile_editing_mode := TileSetPanel.tile_editing_mode
) -> void:
	for cel in cel_dictionary:
		if cel is CelTileMap:
			(cel as CelTileMap).update_tilemap(tile_editing_mode)
