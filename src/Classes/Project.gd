# gdlint: ignore=max-public-methods
class_name Project
extends Reference
# A class for project properties.

var name := "" setget _name_changed
var size: Vector2 setget _size_changed
var undo_redo := UndoRedo.new()
var tiles: Tiles
var undos := 0  # The number of times we added undo properties
var can_undo = true
var fill_color := Color(0)
var has_changed := false setget _has_changed_changed
# frames and layers Arrays should generally only be modified directly when
# opening/creating a project. When modifying the current project, use
# the add/remove/move/swap_frames/layers methods
var frames := []  # Array of Frames (that contain Cels)
var layers := []  # Array of Layers
var current_frame := 0
var current_layer := 0
var selected_cels := [[0, 0]]  # Array of Arrays of 2 integers (frame & layer)

var animation_tags := [] setget _animation_tags_changed  # Array of AnimationTags
var guides := []  # Array of Guides
var brushes := []  # Array of Images
var reference_images := []  # Array of ReferenceImages
var vanishing_points := []  # Array of Vanishing Points
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
	# Prevents memory leak (due to the layers' project reference stopping ref counting from freeing)
	layers.clear()
	Global.projects.erase(self)


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
		var cel: BaseCel = l.new_empty_cel()
		if cel is PixelCel and bottom_layer and fill_color.a > 0:
			cel.image.fill(fill_color)
		frame.cels.append(cel)
		bottom_layer = false
	return frame


func get_current_cel() -> BaseCel:
	return frames[current_frame].cels[current_layer]


func selection_map_changed() -> void:
	var image_texture := ImageTexture.new()
	has_selection = !selection_map.is_invisible()
	if has_selection:
		image_texture.create_from_image(selection_map, 0)
	Global.canvas.selection.marching_ants_outline.texture = image_texture
	var edit_menu_popup: PopupMenu = Global.top_menu_container.edit_menu_button.get_popup()
	edit_menu_popup.set_item_disabled(Global.EditMenu.NEW_BRUSH, !has_selection)


func _selection_offset_changed(value: Vector2) -> void:
	selection_offset = value
	Global.canvas.selection.marching_ants_outline.offset = selection_offset


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
	Global.canvas.tile_mode.update()
	Global.transparent_checker.update_rect()
	Global.animation_timeline.fps_spinbox.value = fps
	Global.horizontal_ruler.update()
	Global.vertical_ruler.update()
	Global.references_panel.project_changed()
	Global.perspective_editor.update_points()
	Global.cursor_position_label.text = "[%s×%s]" % [size.x, size.y]

	Global.window_title = "%s - Pixelorama %s" % [name, Global.current_version]
	if has_changed:
		Global.window_title = Global.window_title + "(*)"

	var save_path = OpenSave.current_save_paths[Global.current_project_index]
	if save_path != "":
		Global.open_sprites_dialog.current_path = save_path
		Global.save_sprites_dialog.current_path = save_path
		Global.top_menu_container.file_menu.set_item_text(
			Global.FileMenu.SAVE, tr("Save") + " %s" % save_path.get_file()
		)
	else:
		Global.top_menu_container.file_menu.set_item_text(Global.FileMenu.SAVE, tr("Save"))

	if !was_exported:
		Global.top_menu_container.file_menu.set_item_text(Global.FileMenu.EXPORT, tr("Export"))
	else:
		if export_overwrite:
			Global.top_menu_container.file_menu.set_item_text(
				Global.FileMenu.EXPORT,
				tr("Overwrite") + " %s" % (file_name + Export.file_format_string(file_format))
			)
		else:
			Global.top_menu_container.file_menu.set_item_text(
				Global.FileMenu.EXPORT,
				tr("Export") + " %s" % (file_name + Export.file_format_string(file_format))
			)

	for j in Tiles.MODE.values():
		Global.top_menu_container.tile_mode_submenu.set_item_checked(j, j == tiles.mode)

	# Change selection effect & bounding rectangle
	Global.canvas.selection.marching_ants_outline.offset = selection_offset
	selection_map_changed()
	Global.canvas.selection.big_bounding_rectangle = selection_map.get_used_rect()
	Global.canvas.selection.big_bounding_rectangle.position += selection_offset
	Global.canvas.selection.update()
	var edit_menu_popup: PopupMenu = Global.top_menu_container.edit_menu_button.get_popup()
	edit_menu_popup.set_item_disabled(Global.EditMenu.NEW_BRUSH, !has_selection)

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
		camera.emit_signal("rotation_changed")
		camera.emit_signal("zoom_changed")
		i += 1
	Global.tile_mode_offset_dialog.change_mask()


func serialize() -> Dictionary:
	var layer_data := []
	for layer in layers:
		layer_data.append(layer.serialize())
		layer_data[-1]["metadata"] = _serialize_metadata(layer)

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

	var reference_image_data := []
	for reference_image in reference_images:
		reference_image_data.append(reference_image.serialize())

	var metadata := _serialize_metadata(self)

	var project_data := {
		"pixelorama_version": Global.current_version,
		"name": name,
		"size_x": size.x,
		"size_y": size.y,
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
		"reference_images": reference_image_data,
		"vanishing_points": vanishing_points,
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
	if dict.has("tile_mode_x_basis_x") and dict.has("tile_mode_x_basis_y"):
		tiles.x_basis.x = dict.tile_mode_x_basis_x
		tiles.x_basis.y = dict.tile_mode_x_basis_y
	if dict.has("tile_mode_y_basis_x") and dict.has("tile_mode_y_basis_y"):
		tiles.y_basis.x = dict.tile_mode_y_basis_x
		tiles.y_basis.y = dict.tile_mode_y_basis_y
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
				_deserialize_metadata(cels[cel_i], cel)
				cel_i += 1
			var duration := 1.0
			if frame.has("duration"):
				duration = frame.duration
			elif dict.has("frame_duration"):
				duration = dict.frame_duration[frame_i]

			var frame_class := Frame.new(cels, duration)
			_deserialize_metadata(frame_class, frame)
			frames.append(frame_class)
			frame_i += 1

		for saved_layer in dict.layers:
			match int(saved_layer.get("type", Global.LayerTypes.PIXEL)):
				Global.LayerTypes.PIXEL:
					layers.append(PixelLayer.new(self))
				Global.LayerTypes.GROUP:
					layers.append(GroupLayer.new(self))
		# Parent references to other layers are created when deserializing
		# a layer, so loop again after creating them:
		for layer_i in dict.layers.size():
			layers[layer_i].index = layer_i
			layers[layer_i].deserialize(dict.layers[layer_i])
			_deserialize_metadata(layers[layer_i], dict.layers[layer_i])
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
	if dict.has("reference_images"):
		for g in dict.reference_images:
			var ri := ReferenceImage.new()
			ri.project = self
			ri.deserialize(g)
			Global.canvas.add_child(ri)
	if dict.has("vanishing_points"):
		vanishing_points = dict.vanishing_points
		Global.perspective_editor.update()
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
	Global.tile_mode_offset_dialog.change_mask()
	size = value
	Global.canvas.crop_rect.reset()


func change_cel(new_frame: int, new_layer := -1) -> void:
	if new_frame < 0:
		new_frame = current_frame
	if new_layer < 0:
		new_layer = current_layer
	Global.canvas.selection.transform_content_confirm()
	# Unpress all buttons
	for i in frames.size():
		var frame_button: BaseButton = Global.frame_hbox.get_child(i)
		frame_button.pressed = false  # Unpress all frame buttons
		for cel_hbox in Global.cel_vbox.get_children():
			if i < cel_hbox.get_child_count():
				cel_hbox.get_child(i).pressed = false  # Unpress all cel buttons

	for layer_button in Global.layer_vbox.get_children():
		layer_button.pressed = false  # Unpress all layer buttons

	if selected_cels.empty():
		selected_cels.append([new_frame, new_layer])
	for cel in selected_cels:  # Press selected buttons
		var frame: int = cel[0]
		var layer: int = cel[1]
		if frame < Global.frame_hbox.get_child_count():
			var frame_button: BaseButton = Global.frame_hbox.get_child(frame)
			frame_button.pressed = true  # Press selected frame buttons

		var layer_vbox_child_count: int = Global.layer_vbox.get_child_count()
		if layer < layer_vbox_child_count:
			var layer_button = Global.layer_vbox.get_child(layer_vbox_child_count - 1 - layer)
			layer_button.pressed = true  # Press selected layer buttons

		var cel_vbox_child_count: int = Global.cel_vbox.get_child_count()
		if layer < cel_vbox_child_count:
			var cel_hbox: Container = Global.cel_vbox.get_child(cel_vbox_child_count - 1 - layer)
			if frame < cel_hbox.get_child_count():
				var cel_button: BaseButton = cel_hbox.get_child(frame)
				cel_button.pressed = true  # Press selected cel buttons

	if new_frame != current_frame:  # If the frame has changed
		current_frame = new_frame
		Global.current_frame_mark_label.text = "%s/%s" % [str(current_frame + 1), frames.size()]
		toggle_frame_buttons()

	if new_layer != current_layer:  # If the layer has changed
		current_layer = new_layer
		toggle_layer_buttons()

	if current_frame < frames.size():  # Set opacity slider
		var cel_opacity: float = frames[current_frame].cels[current_layer].opacity
		Global.layer_opacity_slider.value = cel_opacity * 100
	Global.canvas.update()
	Global.transparent_checker.update_rect()
	Global.emit_signal("cel_changed")


func toggle_frame_buttons() -> void:
	Global.disable_button(Global.remove_frame_button, frames.size() == 1)
	Global.disable_button(Global.move_left_frame_button, frames.size() == 1 or current_frame == 0)
	Global.disable_button(
		Global.move_right_frame_button, frames.size() == 1 or current_frame == frames.size() - 1
	)


func toggle_layer_buttons() -> void:
	if layers.empty() or current_layer >= layers.size():
		return
	var child_count: int = layers[current_layer].get_child_count(true)

	Global.disable_button(
		Global.remove_layer_button,
		layers[current_layer].is_locked_in_hierarchy() or layers.size() == child_count + 1
	)
	Global.disable_button(Global.move_up_layer_button, current_layer == layers.size() - 1)
	Global.disable_button(
		Global.move_down_layer_button,
		current_layer == child_count and not is_instance_valid(layers[current_layer].parent)
	)
	Global.disable_button(
		Global.merge_down_layer_button,
		(
			current_layer == child_count
			or layers[current_layer] is GroupLayer
			or layers[current_layer - 1] is GroupLayer
		)
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
		and layers[0] is PixelLayer
		and frames[0].cels[0].image.is_invisible()
		and animation_tags.size() == 0
	)


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


# Timeline modifications
# Modifying layers or frames Arrays on the current project should generally only be done
# through these methods.
# These allow you to add/remove/move/swap frames/layers/cels. It updates the Animation Timeline
# UI, and updates indices. These are designed to be reversible, meaning that to undo an add, you
# use remove, and vice versa. To undo a move or swap, use move or swap with the parameters swapped.


func add_frames(new_frames: Array, indices: Array) -> void:  # indices should be in ascending order
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
	# Update the frames and frame buttons:
	for f in frames.size():
		Global.frame_hbox.get_child(f).frame = f
		Global.frame_hbox.get_child(f).text = str(f + 1)
	# Update the cel buttons:
	for l in layers.size():
		var cel_hbox: HBoxContainer = Global.cel_vbox.get_child(layers.size() - 1 - l)
		for f in frames.size():
			cel_hbox.get_child(f).frame = f
			cel_hbox.get_child(f).button_setup()
	_set_timeline_first_and_last_frames()


func remove_frames(indices: Array) -> void:  # indices should be in ascending order
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	for i in indices.size():
		# With each removed index, future indices need to be lowered, so subtract by i
		# For each linked cel in the frame, update its layer's cel_link_sets
		for l in layers.size():
			var cel: BaseCel = frames[indices[i] - i].cels[l]
			if cel.link_set != null:
				cel.link_set["cels"].erase(cel)
				if cel.link_set["cels"].empty():
					layers[l].cel_link_sets.erase(cel.link_set)
		# Remove frame
		frames.remove(indices[i] - i)
		Global.animation_timeline.project_frame_removed(indices[i] - i)
	# Update the frames and frame buttons:
	for f in frames.size():
		Global.frame_hbox.get_child(f).frame = f
		Global.frame_hbox.get_child(f).text = str(f + 1)
	# Update the cel buttons:
	for l in layers.size():
		var cel_hbox: HBoxContainer = Global.cel_vbox.get_child(layers.size() - 1 - l)
		for f in frames.size():
			cel_hbox.get_child(f).frame = f
			cel_hbox.get_child(f).button_setup()
	_set_timeline_first_and_last_frames()


func move_frame(from_index: int, to_index: int) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	var frame = frames[from_index]
	frames.remove(from_index)
	Global.animation_timeline.project_frame_removed(from_index)
	frames.insert(to_index, frame)
	Global.animation_timeline.project_frame_added(to_index)
	# Update the frames and frame buttons:
	for f in frames.size():
		Global.frame_hbox.get_child(f).frame = f
		Global.frame_hbox.get_child(f).text = str(f + 1)
	# Update the cel buttons:
	for l in layers.size():
		var cel_hbox: HBoxContainer = Global.cel_vbox.get_child(layers.size() - 1 - l)
		for f in frames.size():
			cel_hbox.get_child(f).frame = f
			cel_hbox.get_child(f).button_setup()
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
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	for i in indices.size():
		layers.insert(indices[i], new_layers[i])
		for f in frames.size():
			frames[f].cels.insert(indices[i], cels[i][f])
		new_layers[i].project = self
		Global.animation_timeline.project_layer_added(indices[i])
	# Update the layer indices and layer/cel buttons:
	for l in layers.size():
		layers[l].index = l
		Global.layer_vbox.get_child(layers.size() - 1 - l).layer = l
		var cel_hbox: HBoxContainer = Global.cel_vbox.get_child(layers.size() - 1 - l)
		for f in frames.size():
			cel_hbox.get_child(f).layer = l
			cel_hbox.get_child(f).button_setup()
	toggle_layer_buttons()


func remove_layers(indices: Array) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	for i in indices.size():
		# With each removed index, future indices need to be lowered, so subtract by i
		layers.remove(indices[i] - i)
		for frame in frames:
			frame.cels.remove(indices[i] - i)
		Global.animation_timeline.project_layer_removed(indices[i] - i)
	# Update the layer indices and layer/cel buttons:
	for l in layers.size():
		layers[l].index = l
		Global.layer_vbox.get_child(layers.size() - 1 - l).layer = l
		var cel_hbox: HBoxContainer = Global.cel_vbox.get_child(layers.size() - 1 - l)
		for f in frames.size():
			cel_hbox.get_child(f).layer = l
			cel_hbox.get_child(f).button_setup()
	toggle_layer_buttons()


# from_indices and to_indicies should be in ascending order
func move_layers(from_indices: Array, to_indices: Array, to_parents: Array) -> void:
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
	# Update the layer indices and layer/cel buttons:
	for l in layers.size():
		layers[l].index = l
		Global.layer_vbox.get_child(layers.size() - 1 - l).layer = l
		var cel_hbox: HBoxContainer = Global.cel_vbox.get_child(layers.size() - 1 - l)
		for f in frames.size():
			cel_hbox.get_child(f).layer = l
			cel_hbox.get_child(f).button_setup()
	toggle_layer_buttons()


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

	# Update the layer indices and layer/cel buttons:
	for l in layers.size():
		layers[l].index = l
		Global.layer_vbox.get_child(layers.size() - 1 - l).layer = l
		var cel_hbox: HBoxContainer = Global.cel_vbox.get_child(layers.size() - 1 - l)
		for f in frames.size():
			cel_hbox.get_child(f).layer = l
			cel_hbox.get_child(f).button_setup()
	toggle_layer_buttons()


func move_cel(from_frame: int, to_frame: int, layer: int) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	var cel: BaseCel = frames[from_frame].cels[layer]
	if from_frame < to_frame:
		for f in range(from_frame, to_frame):  # Forward range
			frames[f].cels[layer] = frames[f + 1].cels[layer]  # Move left
	else:
		for f in range(from_frame, to_frame, -1):  # Backward range
			frames[f].cels[layer] = frames[f - 1].cels[layer]  # Move right
	frames[to_frame].cels[layer] = cel
	Global.animation_timeline.project_cel_removed(from_frame, layer)
	Global.animation_timeline.project_cel_added(to_frame, layer)

	# Update the cel buttons for this layer:
	var cel_hbox: HBoxContainer = Global.cel_vbox.get_child(layers.size() - 1 - layer)
	for f in frames.size():
		cel_hbox.get_child(f).frame = f
		cel_hbox.get_child(f).button_setup()


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
