class_name Project
extends Reference
# A class for project properties.

var name := "" setget _name_changed
var size: Vector2 setget _size_changed
var undo_redo := UndoRedo.new()
var tiles: Tiles
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

var selection_map := SelectionMap.new()
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

var frame_button_node = preload("res://src/UI/Timeline/FrameButton.tscn")
var layer_button_node = preload("res://src/UI/Timeline/LayerButton.tscn")
var cel_button_node = preload("res://src/UI/Timeline/CelButton.tscn")
var animation_tag_node = preload("res://src/UI/Timeline/AnimationTagUI.tscn")


func _init(_frames := [], _name := tr("untitled"), _size := Vector2(64, 64)) -> void:
	frames = _frames
	name = _name
	size = _size
	tiles = Tiles.new(size)
	selection_map.create(size.x, size.y, false, Image.FORMAT_LA8)

	Global.tabs.add_tab(name)
	OpenSave.current_save_paths.append("")
	OpenSave.backup_save_paths.append("")

	x_symmetry_point = size.x
	y_symmetry_point = size.y

	x_symmetry_axis.type = x_symmetry_axis.Types.HORIZONTAL
	x_symmetry_axis.project = self
	x_symmetry_axis.add_point(Vector2(-19999, y_symmetry_point / 2 + 0.5))
	x_symmetry_axis.add_point(Vector2(19999, y_symmetry_point / 2 + 0.5))
	Global.canvas.add_child(x_symmetry_axis)

	y_symmetry_axis.type = y_symmetry_axis.Types.VERTICAL
	y_symmetry_axis.project = self
	y_symmetry_axis.add_point(Vector2(x_symmetry_point / 2 + 0.5, -19999))
	y_symmetry_axis.add_point(Vector2(x_symmetry_point / 2 + 0.5, 19999))
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
		if bottom_layer and fill_color.a > 0:
			image.fill(fill_color)
		frame.cels.append(Cel.new(image, 1))
		bottom_layer = false

	return frame


func selection_map_changed() -> void:
	var image_texture := ImageTexture.new()
	has_selection = !selection_map.is_invisible()
	if has_selection:
		image_texture.create_from_image(selection_map, 0)
	Global.canvas.selection.marching_ants_outline.texture = image_texture
	Global.top_menu_container.edit_menu_button.get_popup().set_item_disabled(6, !has_selection)


func _selection_offset_changed(value: Vector2) -> void:
	selection_offset = value
	Global.canvas.selection.marching_ants_outline.offset = selection_offset
	Global.canvas.selection.update_on_zoom(Global.camera.zoom.x)


func change_project() -> void:
	# Remove old nodes
	for container in Global.layers_container.get_children():
		container.queue_free()

	_remove_cel_buttons()

	for frame_id in Global.frame_ids.get_children():
		Global.frame_ids.remove_child(frame_id)
		frame_id.queue_free()

	# Create new ones
	for i in range(layers.size() - 1, -1, -1):
		# Create layer buttons
		var layer_container = layer_button_node.instance()
		layer_container.layer = i
		if layers[i].name == "":
			layers[i].name = tr("Layer") + " %s" % i

		Global.layers_container.add_child(layer_container)
		layer_container.label.text = layers[i].name
		layer_container.line_edit.text = layers[i].name

		var layer_cel_container := HBoxContainer.new()
		Global.frames_container.add_child(layer_cel_container)
		for j in range(frames.size()):  # Create Cel buttons
			var cel_button = cel_button_node.instance()
			cel_button.frame = j
			cel_button.layer = i
			cel_button.get_child(0).texture = frames[j].cels[i].image_texture
			cel_button.pressed = j == current_frame and i == current_layer

			layer_cel_container.add_child(cel_button)

	for j in range(frames.size()):  # Create frame buttons
		var button: Button = frame_button_node.instance()
		button.frame = j
		button.rect_min_size.x = Global.animation_timeline.cel_size
		button.text = str(j + 1)
		button.pressed = j == current_frame
		Global.frame_ids.add_child(button)

	var layer_button = Global.layers_container.get_child(
		Global.layers_container.get_child_count() - 1 - current_layer
	)
	layer_button.pressed = true

	Global.current_frame_mark_label.text = "%s/%s" % [str(current_frame + 1), frames.size()]

	Global.disable_button(Global.remove_frame_button, frames.size() == 1)
	Global.disable_button(Global.move_left_frame_button, frames.size() == 1 or current_frame == 0)
	Global.disable_button(
		Global.move_right_frame_button, frames.size() == 1 or current_frame == frames.size() - 1
	)
	_toggle_layer_buttons_layers()
	_toggle_layer_buttons_current_layer()

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
	Global.canvas.tile_mode.update()
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

	for j in Tiles.MODE.values():
		Global.top_menu_container.tile_mode_submenu.set_item_checked(j, j == tiles.mode)

	# Change selection effect & bounding rectangle
	Global.canvas.selection.marching_ants_outline.offset = selection_offset
	selection_map_changed()
	Global.canvas.selection.big_bounding_rectangle = selection_map.get_used_rect()
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
		var linked_cels := []
		for cel in layer.linked_cels:
			linked_cels.append(frames.find(cel))

		layer_data.append(
			{
				"name": layer.name,
				"visible": layer.visible,
				"locked": layer.locked,
				"new_cels_linked": layer.new_cels_linked,
				"linked_cels": linked_cels,
				"metadata": _serialize_metadata(layer)
			}
		)

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
			cel_data.append({"opacity": cel.opacity, "metadata": _serialize_metadata(cel)})

		frame_data.append(
			{"cels": cel_data, "duration": frame.duration, "metadata": _serialize_metadata(frame)}
		)
	var brush_data := []
	for brush in brushes:
		brush_data.append({"size_x": brush.get_size().x, "size_y": brush.get_size().y})

	var tile_mask_data := {
		"size_x": tiles.tile_mask.get_size().x, "size_y": tiles.tile_mask.get_size().y
	}

	var metadata := _serialize_metadata(self)

	var project_data := {
		"pixelorama_version": Global.current_version,
		"name": name,
		"size_x": size.x,
		"size_y": size.y,
		"has_mask": tiles.has_mask,
		"tile_mask": tile_mask_data,
		"tile_mode_x_basis_x": tiles.x_basis.x,
		"tile_mode_x_basis_y": tiles.x_basis.y,
		"tile_mode_y_basis_x": tiles.y_basis.x,
		"tile_mode_y_basis_y": tiles.y_basis.y,
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
		"fps": fps,
		"metadata": metadata
	}

	return project_data


func deserialize(dict: Dictionary) -> void:
	if dict.has("name"):
		name = dict.name
	if dict.has("size_x") and dict.has("size_y"):
		size.x = dict.size_x
		size.y = dict.size_y
		tiles.tile_size = size
		selection_map.crop(size.x, size.y)
	if dict.has("has_mask"):
		tiles.has_mask = dict.has_mask
	if dict.has("tile_mode_x_basis_x") and dict.has("tile_mode_x_basis_y"):
		tiles.x_basis.x = dict.tile_mode_x_basis_x
		tiles.x_basis.y = dict.tile_mode_x_basis_y
	if dict.has("tile_mode_y_basis_x") and dict.has("tile_mode_y_basis_y"):
		tiles.y_basis.x = dict.tile_mode_y_basis_x
		tiles.y_basis.y = dict.tile_mode_y_basis_y
	if dict.has("save_path"):
		OpenSave.current_save_paths[Global.projects.find(self)] = dict.save_path
	if dict.has("frames"):
		var frame_i := 0
		for frame in dict.frames:
			var cels := []
			for cel in frame.cels:
				var cel_class := Cel.new(Image.new(), cel.opacity)
				_deserialize_metadata(cel_class, cel)
				cels.append(cel_class)
			var duration := 1.0
			if frame.has("duration"):
				duration = frame.duration
			elif dict.has("frame_duration"):
				duration = dict.frame_duration[frame_i]

			var frame_class := Frame.new(cels, duration)
			_deserialize_metadata(frame_class, frame)
			frames.append(frame_class)
			frame_i += 1

		if dict.has("layers"):
			var layer_i := 0
			for saved_layer in dict.layers:
				var linked_cels := []
				for linked_cel_number in saved_layer.linked_cels:
					linked_cels.append(frames[linked_cel_number])
					var linked_cel: Cel = frames[linked_cel_number].cels[layer_i]
					linked_cel.image = linked_cels[0].cels[layer_i].image
					linked_cel.image_texture = linked_cels[0].cels[layer_i].image_texture
				var layer := Layer.new(
					saved_layer.name,
					saved_layer.visible,
					saved_layer.locked,
					saved_layer.new_cels_linked,
					linked_cels
				)
				_deserialize_metadata(layer, saved_layer)
				layers.append(layer)
				layer_i += 1
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
	_deserialize_metadata(self, dict)


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


func _name_changed(value: String) -> void:
	name = value
	Global.tabs.set_tab_title(Global.tabs.current_tab, name)


func _size_changed(value: Vector2) -> void:
	if size.x != 0:
		tiles.x_basis = (tiles.x_basis * value.x / size.x).round()
	else:
		tiles.x_basis = Vector2(value.x, 0)
	if size.y != 0:
		tiles.y_basis = (tiles.y_basis * value.y / size.y).round()
	else:
		tiles.y_basis = Vector2(0, value.y)
	tiles.tile_size = value
	tiles.reset_mask()
	size = value


func _frames_changed(value: Array) -> void:
	Global.canvas.selection.transform_content_confirm()
	frames = value
	selected_cels.clear()
	_remove_cel_buttons()

	for frame_id in Global.frame_ids.get_children():
		Global.frame_ids.remove_child(frame_id)
		frame_id.queue_free()

	for i in range(layers.size() - 1, -1, -1):
		var layer_cel_container := HBoxContainer.new()
		layer_cel_container.name = "FRAMESS " + str(i)
		Global.frames_container.add_child(layer_cel_container)
		for j in range(frames.size()):
			var cel_button = cel_button_node.instance()
			cel_button.frame = j
			cel_button.layer = i
			cel_button.get_child(0).texture = frames[j].cels[i].image_texture
			layer_cel_container.add_child(cel_button)

	for j in range(frames.size()):
		var button: Button = frame_button_node.instance()
		button.frame = j
		button.rect_min_size.x = Global.animation_timeline.cel_size
		button.text = str(j + 1)
		Global.frame_ids.add_child(button)

	_set_timeline_first_and_last_frames()


func _layers_changed(value: Array) -> void:
	layers = value
	if Global.layers_changed_skip:
		Global.layers_changed_skip = false
		return

	selected_cels.clear()

	for container in Global.layers_container.get_children():
		container.queue_free()

	_remove_cel_buttons()

	for i in range(layers.size() - 1, -1, -1):
		var layer_button: LayerButton = layer_button_node.instance()
		layer_button.layer = i
		if layers[i].name == "":
			layers[i].name = tr("Layer") + " %s" % i

		Global.layers_container.add_child(layer_button)
		layer_button.label.text = layers[i].name
		layer_button.line_edit.text = layers[i].name

		var layer_cel_container := HBoxContainer.new()
		layer_cel_container.name = "LAYERSSS " + str(i)
		Global.frames_container.add_child(layer_cel_container)
		for j in range(frames.size()):
			var cel_button = cel_button_node.instance()
			cel_button.frame = j
			cel_button.layer = i
			cel_button.get_child(0).texture = frames[j].cels[i].image_texture
			layer_cel_container.add_child(cel_button)

	var layer_button = Global.layers_container.get_child(
		Global.layers_container.get_child_count() - 1 - current_layer
	)
	layer_button.pressed = true
	self.current_frame = current_frame  # Call frame_changed to update UI
	_toggle_layer_buttons_layers()


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
		var current_frame_tmp: int = cel[0]
		var current_layer_tmp: int = cel[1]
		if current_frame_tmp < Global.frame_ids.get_child_count():
			var frame_button: BaseButton = Global.frame_ids.get_child(current_frame_tmp)
			frame_button.pressed = true

		var container_child_count: int = Global.frames_container.get_child_count()
		if current_layer_tmp < container_child_count:
			var container = Global.frames_container.get_child(
				container_child_count - 1 - current_layer_tmp
			)
			if current_frame_tmp < container.get_child_count():
				var fbutton = container.get_child(current_frame_tmp)
				fbutton.pressed = true

	Global.disable_button(Global.remove_frame_button, frames.size() == 1)
	Global.disable_button(Global.move_left_frame_button, frames.size() == 1 or current_frame == 0)
	Global.disable_button(
		Global.move_right_frame_button, frames.size() == 1 or current_frame == frames.size() - 1
	)

	if current_frame < frames.size():
		var cel_opacity: float = frames[current_frame].cels[current_layer].opacity
		Global.layer_opacity_slider.value = cel_opacity * 100
		Global.layer_opacity_spinbox.value = cel_opacity * 100

	Global.canvas.update()
	Global.transparent_checker.update_rect()


func _layer_changed(value: int) -> void:
	Global.canvas.selection.transform_content_confirm()
	current_layer = value

	_toggle_layer_buttons_current_layer()

	yield(Global.get_tree().create_timer(0.01), "timeout")
	self.current_frame = current_frame  # Call frame_changed to update UI
	for layer_button in Global.layers_container.get_children():
		layer_button.pressed = false

	for cel in selected_cels:
		var current_layer_tmp: int = cel[1]
		if current_layer_tmp < Global.layers_container.get_child_count():
			var layer_button = Global.layers_container.get_child(
				Global.layers_container.get_child_count() - 1 - current_layer_tmp
			)
			layer_button.pressed = true


func _toggle_layer_buttons_layers() -> void:
	if !layers:
		return
	if layers[current_layer].locked:
		Global.disable_button(Global.remove_layer_button, true)

	if layers.size() == 1:
		Global.disable_button(Global.remove_layer_button, true)
		Global.disable_button(Global.move_up_layer_button, true)
		Global.disable_button(Global.move_down_layer_button, true)
		Global.disable_button(Global.merge_down_layer_button, true)
	elif !layers[current_layer].locked:
		Global.disable_button(Global.remove_layer_button, false)


func _toggle_layer_buttons_current_layer() -> void:
	if current_layer < layers.size() - 1:
		Global.disable_button(Global.move_up_layer_button, false)
	else:
		Global.disable_button(Global.move_up_layer_button, true)

	if current_layer > 0:
		Global.disable_button(Global.move_down_layer_button, false)
		Global.disable_button(Global.merge_down_layer_button, false)
	else:
		Global.disable_button(Global.move_down_layer_button, true)
		Global.disable_button(Global.merge_down_layer_button, true)

	if current_layer < layers.size():
		if layers[current_layer].locked:
			Global.disable_button(Global.remove_layer_button, true)
		else:
			if layers.size() > 1:
				Global.disable_button(Global.remove_layer_button, false)


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
				Global.animation_timeline.last_frame = min(frames.size() - 1, tag.to - 1)


func _has_changed_changed(value: bool) -> void:
	has_changed = value
	if value:
		Global.tabs.set_tab_title(Global.tabs.current_tab, name + "(*)")
	else:
		Global.tabs.set_tab_title(Global.tabs.current_tab, name)


func is_empty() -> bool:
	return (
		frames.size() == 1
		and layers.size() == 1
		and frames[0].cels[0].image.is_invisible()
		and animation_tags.size() == 0
	)


func duplicate_layers() -> Array:
	var new_layers: Array = layers.duplicate()
	# Loop through the array to create new classes for each element, so that they
	# won't be the same as the original array's classes. Needed for undo/redo to work properly.
	for i in new_layers.size():
		var new_linked_cels = new_layers[i].linked_cels.duplicate()
		new_layers[i] = Layer.new(
			new_layers[i].name,
			new_layers[i].visible,
			new_layers[i].locked,
			new_layers[i].new_cels_linked,
			new_linked_cels
		)

	return new_layers


func can_pixel_get_drawn(
	pixel: Vector2,
	image: SelectionMap = selection_map,
	selection_position: Vector2 = Global.canvas.selection.big_bounding_rectangle.position
) -> bool:
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= size.x or pixel.y >= size.y:
		return false

	if tiles.mode != Tiles.MODE.NONE and !tiles.has_point(pixel):
		return false

	if has_selection:
		if selection_position.x < 0:
			pixel.x -= selection_position.x
		if selection_position.y < 0:
			pixel.y -= selection_position.y
		return image.is_pixel_selected(pixel)
	else:
		return true
