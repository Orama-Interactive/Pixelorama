class_name Project
extends Reference
# A class for project properties.

var name := "" setget _name_changed
var size: Vector2 setget _size_changed
var undo_redo := UndoRedo.new()
var tile_mode: int = Global.TileMode.NONE
var tile_mode_rects := []  # Cached to avoid recalculation
var undos := 0  # The number of times we added undo properties
var fill_color := Color(0)
var has_changed := false setget _has_changed_changed
var frames := [] setget _frames_changed  # Array of Frames (that contain Cels)
var layers := [] setget _layers_changed  # Array of Layers
var current_frame := 0 setget _frame_changed
var current_layer := 0 setget _layer_changed
var selected_cels := [[0, 0]]  # Array of Arrays of 2 integers (frame & layer)

var animation_tags := [] setget _animation_tags_changed  # Array of AnimationTags
var guides := []  # Array of Guides
var brushes := []  # Array of Images
var fps := 6.0

var x_symmetry_point
var y_symmetry_point
var x_symmetry_axis := SymmetryGuide.new()
var y_symmetry_axis := SymmetryGuide.new()

var selection_bitmap := BitMap.new()
# This is useful for when the selection is outside of the canvas boundaries,
# on the left and/or above (negative coords)
var selection_offset := Vector2.ZERO setget _selection_offset_changed
var has_selection := false

# For every camera (currently there are 3)
var cameras_rotation := [0.0, 0.0, 0.0]  # Array of float
var cameras_zoom := [Vector2(0.15, 0.15), Vector2(0.15, 0.15), Vector2(0.15, 0.15)]
var cameras_offset := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var cameras_zoom_max := [Vector2.ONE, Vector2.ONE, Vector2.ONE]

# Export directory path and export file name
var directory_path := ""
var file_name := "untitled"
var file_format: int = Export.FileFormat.PNG
var was_exported := false
var export_overwrite := false

# TODO L: Perhaps animation_tags could get a similar refactoring (In a later PR)
var animation_tag_node = preload("res://src/UI/Timeline/AnimationTagUI.tscn")


func _init(_frames := [], _name := tr("untitled"), _size := Vector2(64, 64)) -> void:
	frames = _frames
	name = _name
	size = _size
	selection_bitmap.create(size)
	_update_tile_mode_rects()

	Global.tabs.add_tab(name)
	OpenSave.current_save_paths.append("")
	OpenSave.backup_save_paths.append("")

	x_symmetry_point = size.x / 2
	y_symmetry_point = size.y / 2

	x_symmetry_axis.type = x_symmetry_axis.Types.HORIZONTAL
	x_symmetry_axis.project = self
	x_symmetry_axis.add_point(Vector2(-19999, y_symmetry_point))
	x_symmetry_axis.add_point(Vector2(19999, y_symmetry_point))
	Global.canvas.add_child(x_symmetry_axis)

	y_symmetry_axis.type = y_symmetry_axis.Types.VERTICAL
	y_symmetry_axis.project = self
	y_symmetry_axis.add_point(Vector2(x_symmetry_point, -19999))
	y_symmetry_axis.add_point(Vector2(x_symmetry_point, 19999))
	Global.canvas.add_child(y_symmetry_axis)

	if OS.get_name() == "HTML5":
		directory_path = "user://"
	else:
		directory_path = Global.config_cache.get_value(
			"data", "current_dir", OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
		)


func remove() -> void:
	undo_redo.free()
	for guide in guides:
		guide.queue_free()
	Global.projects.erase(self)


func commit_undo() -> void:
	if Global.canvas.selection.is_moving_content:
		Global.canvas.selection.transform_content_cancel()
	else:
		undo_redo.undo()


func commit_redo() -> void:
	Global.control.redone = true
	undo_redo.redo()
	Global.control.redone = false


func new_empty_frame() -> Frame:
	var frame := Frame.new()
	var bottom_layer := true
	for l in layers:  # Create as many cels as there are layers
		var image := Image.new()
		image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		if bottom_layer:
			image.fill(fill_color)
		frame.cels.append(PixelCel.new(image, 1))
		bottom_layer = false

	return frame


func selection_bitmap_changed() -> void:
	var image := Image.new()
	var image_texture := ImageTexture.new()
	has_selection = selection_bitmap.get_true_bit_count() > 0
	if has_selection:
		image = bitmap_to_image(selection_bitmap)
		image_texture.create_from_image(image, 0)
	Global.canvas.selection.marching_ants_outline.texture = image_texture
	Global.top_menu_container.edit_menu_button.get_popup().set_item_disabled(6, !has_selection)


func _selection_offset_changed(value: Vector2) -> void:
	selection_offset = value
	Global.canvas.selection.marching_ants_outline.offset = selection_offset
	Global.canvas.selection.update_on_zoom(Global.camera.zoom.x)


func change_project() -> void:
	Global.animation_timeline.project_changed()

	Global.current_frame_mark_label.text = "%s/%s" % [str(current_frame + 1), frames.size()]

	Global.disable_button(Global.remove_frame_button, frames.size() == 1)
	Global.disable_button(Global.move_left_frame_button, frames.size() == 1 or current_frame == 0)
	Global.disable_button(
		Global.move_right_frame_button, frames.size() == 1 or current_frame == frames.size() - 1
	)
	toggle_layer_buttons()

	self.animation_tags = animation_tags

	# Change the guides
	for guide in Global.canvas.get_children():
		if guide is Guide:
			if guide in guides:
				guide.visible = Global.show_guides
				if guide is SymmetryGuide:
					if guide.type == Guide.Types.HORIZONTAL:
						guide.visible = Global.show_x_symmetry_axis and Global.show_guides
					else:
						guide.visible = Global.show_y_symmetry_axis and Global.show_guides
			else:
				guide.visible = false

	# Change the project brushes
	Brushes.clear_project_brush()
	for brush in brushes:
		Brushes.add_project_brush(brush)

	Global.canvas.update()
	Global.canvas.grid.update()
	Global.transparent_checker.update_rect()
	Global.animation_timeline.fps_spinbox.value = fps
	Global.horizontal_ruler.update()
	Global.vertical_ruler.update()
	Global.cursor_position_label.text = "[%s×%s]" % [size.x, size.y]

	Global.window_title = "%s - Pixelorama %s" % [name, Global.current_version]
	if has_changed:
		Global.window_title = Global.window_title + "(*)"

	var save_path = OpenSave.current_save_paths[Global.current_project_index]
	if save_path != "":
		Global.open_sprites_dialog.current_path = save_path
		Global.save_sprites_dialog.current_path = save_path
		Global.top_menu_container.file_menu.set_item_text(
			4, tr("Save") + " %s" % save_path.get_file()
		)
	else:
		Global.top_menu_container.file_menu.set_item_text(4, tr("Save"))

	Export.directory_path = directory_path
	Export.file_name = file_name
	Export.file_format = file_format
	Export.was_exported = was_exported

	if !was_exported:
		Global.top_menu_container.file_menu.set_item_text(6, tr("Export"))
	else:
		if export_overwrite:
			Global.top_menu_container.file_menu.set_item_text(
				6, tr("Overwrite") + " %s" % (file_name + Export.file_format_string(file_format))
			)
		else:
			Global.top_menu_container.file_menu.set_item_text(
				6, tr("Export") + " %s" % (file_name + Export.file_format_string(file_format))
			)

	for j in Global.TileMode.values():
		Global.top_menu_container.tile_mode_submenu.set_item_checked(j, j == tile_mode)

	# Change selection effect & bounding rectangle
	Global.canvas.selection.marching_ants_outline.offset = selection_offset
	selection_bitmap_changed()
	Global.canvas.selection.big_bounding_rectangle = get_selection_rectangle()
	Global.canvas.selection.big_bounding_rectangle.position += selection_offset
	Global.canvas.selection.update()
	Global.top_menu_container.edit_menu_button.get_popup().set_item_disabled(6, !has_selection)

	var i := 0
	for camera in Global.cameras:
		camera.zoom_max = cameras_zoom_max[i]
		if camera == Global.camera_preview:
			Global.preview_zoom_slider.disconnect(
				"value_changed",
				Global.canvas_preview_container,
				"_on_PreviewZoomSlider_value_changed"
			)
			Global.preview_zoom_slider.min_value = -camera.zoom_max.x
			Global.preview_zoom_slider.connect(
				"value_changed",
				Global.canvas_preview_container,
				"_on_PreviewZoomSlider_value_changed"
			)

		if camera == Global.camera:
			Global.zoom_level_spinbox.min_value = 100.0 / camera.zoom_max.x
		camera.rotation = cameras_rotation[i]
		camera.zoom = cameras_zoom[i]
		camera.offset = cameras_offset[i]
		camera.rotation_changed()
		camera.zoom_changed()
		i += 1


func serialize() -> Dictionary:
	var layer_data := []
	for layer in layers:
		layer_data.append(layer.serialize())

	var tag_data := []
	for tag in animation_tags:
		tag_data.append(
			{
				"name": tag.name,
				"color": tag.color.to_html(),
				"from": tag.from,
				"to": tag.to,
			}
		)

	var guide_data := []
	for guide in guides:
		if guide is SymmetryGuide:
			continue
		if !is_instance_valid(guide):
			continue
		var coords = guide.points[0].x
		if guide.type == Guide.Types.HORIZONTAL:
			coords = guide.points[0].y

		guide_data.append({"type": guide.type, "pos": coords})

	var frame_data := []
	for frame in frames:
		var cel_data := []
		for cel in frame.cels:
			cel_data.append(
				{
					"opacity": cel.opacity,
				}
			)
		frame_data.append({"cels": cel_data, "duration": frame.duration})
	var brush_data := []
	for brush in brushes:
		brush_data.append({"size_x": brush.get_size().x, "size_y": brush.get_size().y})

	var project_data := {
		"pixelorama_version": Global.current_version,
		"name": name,
		"size_x": size.x,
		"size_y": size.y,
		"save_path": OpenSave.current_save_paths[Global.projects.find(self)],
		"layers": layer_data,
		"tags": tag_data,
		"guides": guide_data,
		"symmetry_points": [x_symmetry_point, y_symmetry_point],
		"frames": frame_data,
		"brushes": brush_data,
		"export_directory_path": directory_path,
		"export_file_name": file_name,
		"export_file_format": file_format,
		"fps": fps
	}

	return project_data


func deserialize(dict: Dictionary) -> void:
	if dict.has("name"):
		name = dict.name
	if dict.has("size_x") and dict.has("size_y"):
		size.x = dict.size_x
		size.y = dict.size_y

		_update_tile_mode_rects()
		selection_bitmap = resize_bitmap(selection_bitmap, size)
	if dict.has("save_path"):
		OpenSave.current_save_paths[Global.projects.find(self)] = dict.save_path
	if dict.has("frames") and dict.has("layers"):
		var frame_i := 0
		for frame in dict.frames:
			var cels := []
			var cel_i := 0
			for cel in frame.cels:
				match int(dict.layers[cel_i].get("type", Global.LayerTypes.PIXEL)):
					Global.LayerTypes.PIXEL:
						cels.append(PixelCel.new(Image.new(), cel.opacity))
					Global.LayerTypes.GROUP:
						cels.append(GroupCel.new(cel.opacity))
				cel_i += 1
			var duration := 1.0
			if frame.has("duration"):
				duration = frame.duration
			elif dict.has("frame_duration"):
				duration = dict.frame_duration[frame_i]

			frames.append(Frame.new(cels, duration))
			frame_i += 1

		for saved_layer in dict.layers:
			match int(saved_layer.get("type", Global.LayerTypes.PIXEL)):
				Global.LayerTypes.PIXEL:
					layers.append(PixelLayer.new())
				Global.LayerTypes.GROUP:
					layers.append(GroupLayer.new())
		# Parent references to other layers are created when deserializing
		# a layer, so loop again after creating them:
		for layer_i in range(dict.layers.size()):
			layers[layer_i].project = self
			layers[layer_i].index = layer_i
			layers[layer_i].deserialize(dict.layers[layer_i])
	if dict.has("tags"):
		for tag in dict.tags:
			animation_tags.append(AnimationTag.new(tag.name, Color(tag.color), tag.from, tag.to))
		self.animation_tags = animation_tags
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
	if dict.has("symmetry_points"):
		x_symmetry_point = dict.symmetry_points[0]
		y_symmetry_point = dict.symmetry_points[1]
		for point in x_symmetry_axis.points.size():
			x_symmetry_axis.points[point].y = floor(y_symmetry_point / 2 + 1)
		for point in y_symmetry_axis.points.size():
			y_symmetry_axis.points[point].x = floor(x_symmetry_point / 2 + 1)
	if dict.has("export_directory_path"):
		directory_path = dict.export_directory_path
	if dict.has("export_file_name"):
		file_name = dict.export_file_name
	if dict.has("export_file_format"):
		file_format = dict.export_file_format
	if dict.has("fps"):
		fps = dict.fps


func _name_changed(value: String) -> void:
	name = value
	Global.tabs.set_tab_title(Global.tabs.current_tab, name)


func _size_changed(value: Vector2) -> void:
	size = value
	_update_tile_mode_rects()


func _frames_changed(value: Array) -> void:
	Global.canvas.selection.transform_content_confirm()
	frames = value
#	selected_cels.clear() # TODO R4: Determine if this needs to be kept (If it is, selected cels needs to be intialized after creating project (ie: in Main), rather than here
	# TODO NOTE: perhaps if you don't clear the selected cels, some invalid ones may be included? (ie: removed cels?)
	# 			selected cels is already cleared when using the new frame/layer/cel functions
	#			THESE SHOULD PROBABLY BE SAFE TO REMOVE FOR NORMAL USAGE, IS THERE A PLACE WHERE THEY'RE NOT?
	#			OTHER THAN ON STARTUP, IS THERE ANY DISADVANGTAGE TO KEEPING? (may be better to keep just to be sure)
	print(selected_cels)
	for c in selected_cels:
		if c[0] >= frames.size():
			print("invalid frame in selected cel")
	# REMOVE ALL THAT DEBUG CODE ^^^^^^^^^^^^^^^^

	_set_timeline_first_and_last_frames()


func _layers_changed(value: Array) -> void:
	layers = value
	if Global.layers_changed_skip:
		Global.layers_changed_skip = false
		return

#	selected_cels.clear() # TODO R4: Determine if this needs to be kept (If it is, selected cels needs to be intialized after creating project (ie: in Main), rather than here
	# TODO NOTE: perhaps if you don't clear the selected cels, some invalid ones may be included? (ie: removed cels?)
	# 			selected cels is already cleared when using the new frame/layer/cel functions
	#			THESE SHOULD PROBABLY BE SAFE TO REMOVE FOR NORMAL USAGE, IS THERE A PLACE WHERE THEY'RE NOT?
	#			OTHER THAN ON STARTUP, IS THERE ANY DISADVANGTAGE TO KEEPING? (may be better to keep just to be sure)
	for c in selected_cels:
		if c[1] >= layers.size():
			print("invalid layer in selected cel")
	# REMOVE ALL THAT DEBUG CODE ^^^^^^^^^^^^^^^^

	# TODO R4: investigate wether these are still required (Should be safe to remove):
#	var layer_button = Global.layers_container.get_child(
#		Global.layers_container.get_child_count() - 1 - current_layer
#	)
#	layer_button.pressed = true
#	self.current_frame = current_frame  # Call frame_changed to update UI
	toggle_layer_buttons()


func _remove_cel_buttons() -> void:
	for container in Global.frames_container.get_children():
		Global.frames_container.remove_child(container)
		container.queue_free()


func _frame_changed(value: int) -> void:
	Global.canvas.selection.transform_content_confirm()
	current_frame = value
	Global.current_frame_mark_label.text = "%s/%s" % [str(current_frame + 1), frames.size()]

	for i in frames.size():
		var frame_button: BaseButton = Global.frame_ids.get_child(i)
		frame_button.pressed = false
		for container in Global.frames_container.get_children():  # De-select all the other cels
			if i < container.get_child_count():
				container.get_child(i).pressed = false

	if selected_cels.empty():
		selected_cels.append([current_frame, current_layer])
	# Select the new frame
	for cel in selected_cels:
		var frame: int = cel[0]
		var layer: int = cel[1]
		if frame < Global.frame_ids.get_child_count():
			var frame_button: BaseButton = Global.frame_ids.get_child(frame)
			frame_button.pressed = true

		var container_child_count: int = Global.frames_container.get_child_count()
		if layer < container_child_count:
			var container = Global.frames_container.get_child(
				container_child_count - 1 - layer
			)
			if frame < container.get_child_count():
				var cel_button = container.get_child(frame)
				cel_button.pressed = true

	if current_frame < frames.size():
		var cel_opacity: float = frames[current_frame].cels[current_layer].opacity
		Global.layer_opacity_slider.value = cel_opacity * 100
		Global.layer_opacity_spinbox.value = cel_opacity * 100

	toggle_frame_buttons()
	Global.canvas.update()
	Global.transparent_checker.update_rect()


func _layer_changed(value: int) -> void:
	Global.canvas.selection.transform_content_confirm()
	current_layer = value

	toggle_layer_buttons()

	yield(Global.get_tree().create_timer(0.01), "timeout")
	self.current_frame = current_frame  # Call frame_changed to update UI
	for layer_button in Global.layers_container.get_children():
		layer_button.pressed = false

	for cel in selected_cels:
		var layer: int = cel[1]
		if layer < Global.layers_container.get_child_count():
			var layer_button = Global.layers_container.get_child(
				Global.layers_container.get_child_count() - 1 - layer
			)
			layer_button.pressed = true


func toggle_frame_buttons() -> void:
	Global.disable_button(Global.remove_frame_button, frames.size() == 1)
	Global.disable_button(Global.move_left_frame_button, frames.size() == 1 or current_frame == 0)
	Global.disable_button(
		Global.move_right_frame_button, frames.size() == 1 or current_frame == frames.size() - 1
	)


func toggle_layer_buttons() -> void:
	if layers.empty() or current_layer >= layers.size():
		return
	var child_count: int = layers[current_layer].get_children_recursive().size()

	Global.disable_button(Global.remove_layer_button,
		layers[current_layer].is_locked_in_hierarchy()
		or layers.size() == child_count + 1
	)
	Global.disable_button(Global.move_up_layer_button, current_layer == layers.size() - 1)
	Global.disable_button(Global.move_down_layer_button,
		current_layer == child_count
		and not is_instance_valid(layers[current_layer].parent)
	)
	Global.disable_button(Global.merge_down_layer_button,
		current_layer == child_count
		or layers[current_layer] is GroupLayer
		or layers[current_layer - 1] is GroupLayer
	)


func _animation_tags_changed(value: Array) -> void:
	animation_tags = value
	for child in Global.tag_container.get_children():
		child.queue_free()

	for tag in animation_tags:
		var tag_base_size = Global.animation_timeline.cel_size + 4
		var tag_c: Container = animation_tag_node.instance()
		Global.tag_container.add_child(tag_c)
		tag_c.tag = tag
		var tag_position: int = Global.tag_container.get_child_count() - 1
		Global.tag_container.move_child(tag_c, tag_position)
		tag_c.get_node("Label").text = tag.name
		tag_c.get_node("Label").modulate = tag.color
		tag_c.get_node("Line2D").default_color = tag.color

		# Added 1 to answer to get starting position of next cel
		tag_c.rect_position.x = (tag.from - 1) * tag_base_size + 1
		var tag_size: int = tag.to - tag.from
		# We dont need the 4 pixels at the end of last cel
		tag_c.rect_min_size.x = (tag_size + 1) * tag_base_size - 8
		tag_c.rect_position.y = 1  # To make top line of tag visible
		tag_c.get_node("Line2D").points[2] = Vector2(tag_c.rect_min_size.x, 0)
		tag_c.get_node("Line2D").points[3] = Vector2(tag_c.rect_min_size.x, 32)

	_set_timeline_first_and_last_frames()

# TODO R1: Is this really required in _frames_changed (or the add/remove frame funcs, seems to work fine without when playing anim)
func _set_timeline_first_and_last_frames() -> void:
	# This is useful in case tags get modified DURING the animation is playing
	# otherwise, this code is useless in this context, since these values are being set
	# when the play buttons get pressed anyway
	Global.animation_timeline.first_frame = 0
	Global.animation_timeline.last_frame = frames.size() - 1
	# TODO NOTE: Perhaps its needed fo the play_only_tags bit?
	if Global.play_only_tags:
		for tag in animation_tags:
			if current_frame + 1 >= tag.from && current_frame + 1 <= tag.to:
				Global.animation_timeline.first_frame = tag.from - 1
				Global.animation_timeline.last_frame = min(frames.size() - 1, tag.to - 1)


func _has_changed_changed(value: bool) -> void:
	has_changed = value
	if value:
		Global.tabs.set_tab_title(Global.tabs.current_tab, name + "(*)")
	else:
		Global.tabs.set_tab_title(Global.tabs.current_tab, name)


func get_tile_mode_rect() -> Rect2:
	return tile_mode_rects[tile_mode]


func _update_tile_mode_rects() -> void:
	tile_mode_rects.resize(Global.TileMode.size())
	tile_mode_rects[Global.TileMode.NONE] = Rect2(Vector2.ZERO, size)
	tile_mode_rects[Global.TileMode.BOTH] = Rect2(Vector2(-1, -1) * size, Vector2(3, 3) * size)
	tile_mode_rects[Global.TileMode.X_AXIS] = Rect2(Vector2(-1, 0) * size, Vector2(3, 1) * size)
	tile_mode_rects[Global.TileMode.Y_AXIS] = Rect2(Vector2(0, -1) * size, Vector2(1, 3) * size)


func is_empty() -> bool:
	return (
		frames.size() == 1
		and layers.size() == 1
		and layers[0] is PixelLayer
		and frames[0].cels[0].image.is_invisible()
		and animation_tags.size() == 0
	)


func duplicate_layers() -> Array:
	var new_layers: Array = layers.duplicate()
	# Loop through the array to create new classes for each element, so that they
	# won't be the same as the original array's classes. Needed for undo/redo to work properly.
	for i in new_layers.size():
		new_layers[i] = new_layers[i].copy()
	for l in new_layers:
		if is_instance_valid(l.parent):
			l.parent = new_layers[l.parent.index] # Update the parent to the new copy of the parent
	return new_layers


func can_pixel_get_drawn(
	pixel: Vector2,
	bitmap: BitMap = selection_bitmap,
	selection_position: Vector2 = Global.canvas.selection.big_bounding_rectangle.position
) -> bool:
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= size.x or pixel.y >= size.y:
		return false

	if has_selection:
		if selection_position.x < 0:
			pixel.x -= selection_position.x
		if selection_position.y < 0:
			pixel.y -= selection_position.y
		return bitmap.get_bit(pixel)
	else:
		return true


func invert_bitmap(bitmap: BitMap) -> void:
	for x in bitmap.get_size().x:
		for y in bitmap.get_size().y:
			var pos := Vector2(x, y)
			bitmap.set_bit(pos, !bitmap.get_bit(pos))


# Unexposed BitMap class function
# https://github.com/godotengine/godot/blob/master/scene/resources/bit_map.cpp#L605
func resize_bitmap(bitmap: BitMap, new_size: Vector2) -> BitMap:
	if new_size == bitmap.get_size():
		return bitmap
	var new_bitmap := BitMap.new()
	new_bitmap.create(new_size)
	var lw = min(bitmap.get_size().x, new_size.x)
	var lh = min(bitmap.get_size().y, new_size.y)
	for x in lw:
		for y in lh:
			new_bitmap.set_bit(Vector2(x, y), bitmap.get_bit(Vector2(x, y)))

	return new_bitmap


# Unexposed BitMap class function
# https://github.com/godotengine/godot/blob/master/scene/resources/bit_map.cpp#L622
func bitmap_to_image(bitmap: BitMap) -> Image:
	var image := Image.new()
	var width := bitmap.get_size().x
	var height := bitmap.get_size().y
	image.create(width, height, false, Image.FORMAT_LA8)
	image.lock()
	for x in width:
		for y in height:
			var pos := Vector2(x, y)
			var color = Color(1, 1, 1, 1) if bitmap.get_bit(pos) else Color(0, 0, 0, 0)
			image.set_pixelv(pos, color)
	image.unlock()
	return image


# Algorithm taken from Image.get_used_rect()
# https://github.com/godotengine/godot/blob/master/core/io/image.cpp
func get_selection_rectangle(bitmap: BitMap = selection_bitmap) -> Rect2:
	if bitmap.get_true_bit_count() == 0:
		return Rect2()

	var minx := 0xFFFFFF
	var miny := 0xFFFFFF
	var maxx := -1
	var maxy := -1
	for j in bitmap.get_size().y:
		for i in bitmap.get_size().x:
			if !bitmap.get_bit(Vector2(i, j)):
				continue
			if i > maxx:
				maxx = i
			if j > maxy:
				maxy = j
			if i < minx:
				minx = i
			if j < miny:
				miny = j

	if maxx == -1:
		return Rect2()
	else:
		return Rect2(minx, miny, maxx - minx + 1, maxy - miny + 1)


func move_bitmap_values(bitmap: BitMap, move_offset := true) -> void:
	var selection_node = Global.canvas.selection
	var selection_position: Vector2 = selection_node.big_bounding_rectangle.position
	var selection_end: Vector2 = selection_node.big_bounding_rectangle.end

	var image: Image = bitmap_to_image(bitmap)
	var selection_rect := image.get_used_rect()
	var smaller_image := image.get_rect(selection_rect)
	image.fill(Color(0))
	var dst := selection_position
	var x_diff = selection_end.x - size.x
	var y_diff = selection_end.y - size.y
	var nw = max(size.x, size.x + x_diff)
	var nh = max(size.y, size.y + y_diff)

	if selection_position.x < 0:
		nw -= selection_position.x
		if move_offset:
			self.selection_offset.x = selection_position.x
		dst.x = 0
	else:
		if move_offset:
			self.selection_offset.x = 0
	if selection_position.y < 0:
		nh -= selection_position.y
		if move_offset:
			self.selection_offset.y = selection_position.y
		dst.y = 0
	else:
		if move_offset:
			self.selection_offset.y = 0

	if nw <= image.get_size().x:
		nw = image.get_size().x
	if nh <= image.get_size().y:
		nh = image.get_size().y

	image.crop(nw, nh)
	image.blit_rect(smaller_image, Rect2(Vector2.ZERO, Vector2(nw, nh)), dst)
	bitmap.create_from_image_alpha(image)


func resize_bitmap_values(bitmap: BitMap, new_size: Vector2, flip_x: bool, flip_y: bool) -> BitMap:
	var selection_node = Global.canvas.selection
	var selection_position: Vector2 = selection_node.big_bounding_rectangle.position
	var dst := selection_position
	var new_bitmap_size := size
	new_bitmap_size.x = max(size.x, abs(selection_position.x) + new_size.x)
	new_bitmap_size.y = max(size.y, abs(selection_position.y) + new_size.y)
	var new_bitmap := BitMap.new()
	var image: Image = bitmap_to_image(bitmap)
	var selection_rect := image.get_used_rect()
	var smaller_image := image.get_rect(selection_rect)
	if selection_position.x <= 0:
		self.selection_offset.x = selection_position.x
		dst.x = 0
	else:
		self.selection_offset.x = 0
	if selection_position.y <= 0:
		self.selection_offset.y = selection_position.y
		dst.y = 0
	else:
		self.selection_offset.y = 0
	image.fill(Color(0))
	smaller_image.resize(new_size.x, new_size.y, Image.INTERPOLATE_NEAREST)
	if flip_x:
		smaller_image.flip_x()
	if flip_y:
		smaller_image.flip_y()
	if new_bitmap_size != size:
		image.crop(new_bitmap_size.x, new_bitmap_size.y)
	image.blit_rect(smaller_image, Rect2(Vector2.ZERO, new_bitmap_size), dst)
	new_bitmap.create_from_image_alpha(image)

	return new_bitmap


func add_frames(new_frames: Array, indices: Array) -> void:  # indices should be in ascending order
	assert(self == Global.current_project) # TODO R3: Remove (Things like calling project_frame/layer_added may need to do a check if its the current project if this fails)
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	for i in range(new_frames.size()):
		frames.insert(indices[i], new_frames[i])
		Global.animation_timeline.project_frame_added(indices[i])
	# Update the frames and frame buttons:
	for f in range(frames.size()):
		Global.frame_ids.get_child(f).frame = f
		Global.frame_ids.get_child(f).text = str(f + 1)
	# Update the cel buttons:
	for l in range(layers.size()):
		var layer_cel_container = Global.frames_container.get_child(layers.size() - 1 - l)
		for f in range(frames.size()):
			layer_cel_container.get_child(f).frame = f
			layer_cel_container.get_child(f).button_setup()
	_set_timeline_first_and_last_frames()


func remove_frames(indices: Array) -> void:  # indices should be in ascending order
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	# TODO R1: Could one half of cel linking and animation tags be included in the add or remove_frame functions? (ie: removing works, but adding doesn't?)
	for i in range(indices.size()):
		# With each removed index, future indices need to be lowered, so subtract by i
		frames.remove(indices[i] - i)
		Global.animation_timeline.project_frame_removed(indices[i] - i)
	# Update the frames and frame buttons:
	for f in range(frames.size()):
		Global.frame_ids.get_child(f).frame = f
		Global.frame_ids.get_child(f).text = str(f + 1)
	# Update the cel buttons:
	for l in range(layers.size()):
		var layer_cel_container = Global.frames_container.get_child(layers.size() - 1 - l)
		for f in range(frames.size()):
			layer_cel_container.get_child(f).frame = f
			layer_cel_container.get_child(f).button_setup()
	_set_timeline_first_and_last_frames()


func move_frame(from_index: int, to_index: int) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	var frame = frames[from_index]
	frames.remove(from_index) # TODO: Maybe the insert(pop_at) trick will work here?
	Global.animation_timeline.project_frame_removed(from_index)
	frames.insert(to_index, frame)
	Global.animation_timeline.project_frame_added(to_index)
	# Update the frames and frame buttons:
	for f in range(frames.size()):
		Global.frame_ids.get_child(f).frame = f
		Global.frame_ids.get_child(f).text = str(f + 1)
	# Update the cel buttons:
	for l in range(layers.size()):
		var layer_cel_container = Global.frames_container.get_child(layers.size() - 1 - l)
		for f in range(frames.size()):
			layer_cel_container.get_child(f).frame = f
			layer_cel_container.get_child(f).button_setup()
	_set_timeline_first_and_last_frames()


func swap_frame(a_index: int, b_index: int) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	var temp: Frame = frames[a_index]
	frames[a_index] = frames[b_index]
	frames[b_index] = temp
	Global.animation_timeline.project_frame_removed(a_index)
	Global.animation_timeline.project_frame_added(a_index)
	Global.animation_timeline.project_frame_removed(b_index)
	Global.animation_timeline.project_frame_added(b_index)
	_set_timeline_first_and_last_frames()


func add_layers(new_layers: Array, indices: Array, cels: Array) -> void:  # cels is 2d Array of cels
	assert(self == Global.current_project) # TODO R3: Remove (Things like calling project_frame/layer_added may need to do a check if its the current project if this fails)
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	for i in range(indices.size()):
		layers.insert(indices[i], new_layers[i])
		for f in range(frames.size()):
			frames[f].cels.insert(indices[i], cels[i][f])
		new_layers[i].project = self
		Global.animation_timeline.project_layer_added(indices[i])
	# Update the layer indices and layer/cel buttons:
	for l in range(layers.size()):
		layers[l].index = l
		Global.layers_container.get_child(layers.size() - 1 - l).layer = l
		var layer_cel_container = Global.frames_container.get_child(layers.size() - 1 - l)
		for f in range(frames.size()):
			layer_cel_container.get_child(f).layer = l
			layer_cel_container.get_child(f).button_setup()
	toggle_layer_buttons()


func remove_layers(indices: Array) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	for i in range(indices.size()):
		# With each removed index, future indices need to be lowered, so subtract by i
		layers.remove(indices[i] - i)
		for frame in frames:
			frame.cels.remove(indices[i] - i)
		Global.animation_timeline.project_layer_removed(indices[i] - i)
	# Update the layer indices and layer/cel buttons:
	for l in range(layers.size()):
		layers[l].index = l
		Global.layers_container.get_child(layers.size() - 1 - l).layer = l
		var layer_cel_container = Global.frames_container.get_child(layers.size() - 1 - l)
		for f in range(frames.size()):
			layer_cel_container.get_child(f).layer = l
			layer_cel_container.get_child(f).button_setup()
	toggle_layer_buttons()


# from_indices and to_indicies should be in ascending order
func move_layers(from_indices: Array, to_indices: Array, to_parents: Array) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	var removed_layers := []
	var removed_cels := [] # 2D array of cels (an array for each layer removed)

	for i in from_indices.size():
		# With each removed index, future indices need to be lowered, so subtract by i
		removed_layers.append(layers.pop_at(from_indices[i] - i))
		removed_layers[i].parent = to_parents[i] # parents must be set before UI created in next loop
		removed_cels.append([])
		for frame in frames:
			removed_cels[i].append(frame.cels.pop_at(from_indices[i] - i))
		Global.animation_timeline.project_layer_removed(from_indices[i] - i)
	for i in to_indices.size():
		layers.insert(to_indices[i], removed_layers[i])
		for f in range(frames.size()):
			frames[f].cels.insert(to_indices[i], removed_cels[i][f])
		Global.animation_timeline.project_layer_added(to_indices[i])
	# Update the layer indices and layer/cel buttons:
	for l in range(layers.size()):
		layers[l].index = l
		Global.layers_container.get_child(layers.size() - 1 - l).layer = l
		var layer_cel_container = Global.frames_container.get_child(layers.size() - 1 - l)
		for f in range(frames.size()):
			layer_cel_container.get_child(f).layer = l
			layer_cel_container.get_child(f).button_setup()
	toggle_layer_buttons()


# "a" and "b" should both contain "from", "to", and "to_parents" arrays.
# (Using dictionaries because there seems to be a limit of 5 arguments for do/undo method calls)
func swap_layers(a: Dictionary, b: Dictionary) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	print("a: ", a, "  b: ", b) # TODO R3: Remove
	var a_layers := []
	var b_layers := []
	var a_cels := [] # 2D array of cels (an array for each layer removed)
	var b_cels := [] # 2D array of cels (an array for each layer removed)
	for i in a.from.size():
		a_layers.append(layers.pop_at(a.from[i] - i))
		Global.animation_timeline.project_layer_removed(a.from[i] - i)
		a_layers[i].parent = a.to_parents[i] # All parents must be set early, before creating buttons
		a_cels.append([])
		for frame in frames:
			a_cels[i].append(frame.cels.pop_at(a.from[i] - i))
	for i in b.from.size():
		var index = (b.from[i] - i) if a.from[0] > b.from[0] else (b.from[i] - i - a.from.size())
		b_layers.append(layers.pop_at(index))
		Global.animation_timeline.project_layer_removed(index)
		b_layers[i].parent = b.to_parents[i] # All parents must be set early, before creating buttons
		b_cels.append([])
		for frame in frames:
			b_cels[i].append(frame.cels.pop_at(index))

	for i in a_layers.size():
		var index = a.to[i] if a.to[0] < b.to[0] else (a.to[i] - b.to.size())
		layers.insert(index, a_layers[i])
		for f in range(frames.size()):
			frames[f].cels.insert(index, a_cels[i][f])
		Global.animation_timeline.project_layer_added(index)
	for i in b_layers.size():
		layers.insert(b.to[i], b_layers[i])
		for f in range(frames.size()):
			frames[f].cels.insert(b.to[i], b_cels[i][f])
		Global.animation_timeline.project_layer_added(b.to[i])

	# Update the layer indices and layer/cel buttons:
	for l in range(layers.size()):
		layers[l].index = l
		Global.layers_container.get_child(layers.size() - 1 - l).layer = l
		var layer_cel_container = Global.frames_container.get_child(layers.size() - 1 - l)
		for f in range(frames.size()):
			layer_cel_container.get_child(f).layer = l
			layer_cel_container.get_child(f).button_setup()
	toggle_layer_buttons()


func move_cel(from_frame: int, to_frame: int, layer: int) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	var cel: BaseCel = frames[from_frame].cels[layer]
	if from_frame < to_frame:
		for f in range(from_frame, to_frame): # Forward range
			frames[f].cels[layer] = frames[f + 1].cels[layer] # Move left
	else:
		for f in range(from_frame, to_frame, -1): # Backward range
			frames[f].cels[layer] = frames[f - 1].cels[layer] # Move right
	frames[to_frame].cels[layer] = cel
	Global.animation_timeline.project_cel_removed(from_frame, layer)
	Global.animation_timeline.project_cel_added(to_frame, layer)

	# Update the cel buttons for this layer:
	var layer_cel_container = Global.frames_container.get_child(layers.size() - 1 - layer)
	for f in range(frames.size()):
		layer_cel_container.get_child(f).frame = f
		layer_cel_container.get_child(f).button_setup()


func swap_cel(a_frame: int, a_layer: int, b_frame: int, b_layer: int) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	var temp: BaseCel = frames[a_frame].cels[a_layer]
	frames[a_frame].cels[a_layer] = frames[b_frame].cels[b_layer]
	frames[b_frame].cels[b_layer] = temp
	Global.animation_timeline.project_cel_removed(a_frame, a_layer)
	Global.animation_timeline.project_cel_added(a_frame, a_layer)
	Global.animation_timeline.project_cel_removed(b_frame, b_layer)
	Global.animation_timeline.project_cel_added(b_frame, b_layer)


func _update_animation_timeline_selection() -> void:
	for cel in selected_cels:
		var frame: int = cel[0]
		var layer: int = cel[1]
		if frame < Global.frame_ids.get_child_count():
			var frame_button: BaseButton = Global.frame_ids.get_child(frame)
			frame_button.pressed = true

		var container_child_count: int = Global.frames_container.get_child_count()
		if layer < container_child_count:
			var container = Global.frames_container.get_child(
				container_child_count - 1 - layer
			)
			if frame < container.get_child_count():
				var cel_button = container.get_child(frame)
				cel_button.pressed = true

			var layer_button = Global.layers_container.get_child(
				container_child_count - 1 - layer
			)
			layer_button.pressed = true
