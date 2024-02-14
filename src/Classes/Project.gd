# gdlint: ignore=max-public-methods
class_name Project
extends RefCounted
## A class for project properties.

signal serialized(Dictionary)
signal about_to_deserialize(Dictionary)

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
var fill_color := Color(0)
var has_changed := false:
	set(value):
		has_changed = value
		if value:
			Global.project_changed.emit(self)
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
var fps := 6.0

var x_symmetry_point: float
var y_symmetry_point: float
var x_symmetry_axis := SymmetryGuide.new()
var y_symmetry_axis := SymmetryGuide.new()

var selection_map := SelectionMap.new()
## This is useful for when the selection is outside of the canvas boundaries,
## on the left and/or above (negative coords)
var selection_offset := Vector2i.ZERO:
	set(value):
		selection_offset = value
		Global.canvas.selection.marching_ants_outline.offset = selection_offset
var has_selection := false

## For every camera (currently there are 3)
var cameras_rotation: PackedFloat32Array = [0.0, 0.0, 0.0]
var cameras_zoom: PackedVector2Array = [
	Vector2(0.15, 0.15), Vector2(0.15, 0.15), Vector2(0.15, 0.15)
]
var cameras_offset: PackedVector2Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]

# Export directory path and export file name
var directory_path := ""
var file_name := "untitled"
var file_format := Export.FileFormat.PNG
var was_exported := false
var export_overwrite := false

var animation_tag_node := preload("res://src/UI/Timeline/AnimationTagUI.tscn")


func _init(_frames: Array[Frame] = [], _name := tr("untitled"), _size := Vector2i(64, 64)) -> void:
	frames = _frames
	name = _name
	size = _size
	tiles = Tiles.new(size)
	selection_map.copy_from(Image.create(size.x, size.y, false, Image.FORMAT_LA8))

	Global.tabs.add_tab(name)
	OpenSave.current_save_paths.append("")
	OpenSave.backup_save_paths.append("")

	x_symmetry_point = size.x - 1
	y_symmetry_point = size.y - 1

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

	if OS.get_name() == "Web":
		directory_path = "user://"
	else:
		directory_path = Global.config_cache.get_value(
			"data", "current_dir", OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
		)
	Global.project_created.emit(self)


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
	for frame in frames:
		for l in layers.size():
			var cel: BaseCel = frame.cels[l]
			cel.on_remove()
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
		var cel := l.new_empty_cel()
		if cel is PixelCel and bottom_layer and fill_color.a > 0:
			cel.image.fill(fill_color)
		frame.cels.append(cel)
		bottom_layer = false
	return frame


## Returns the currently selected [BaseCel].
func get_current_cel() -> BaseCel:
	return frames[current_frame].cels[current_layer]


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

	Global.current_frame_mark_label.text = "%s/%s" % [str(current_frame + 1), frames.size()]
	animation_tags = animation_tags

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

	Global.transparent_checker.update_rect()
	Global.animation_timeline.fps_spinbox.value = fps
	Global.perspective_editor.update_points()
	Global.cursor_position_label.text = "[%s×%s]" % [size.x, size.y]

	Global.main_window.title = "%s - Pixelorama %s" % [name, Global.current_version]
	if has_changed:
		Global.main_window.title = Global.main_window.title + "(*)"

	var save_path := OpenSave.current_save_paths[Global.current_project_index]
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
	Global.canvas.selection.queue_redraw()
	var edit_menu_popup: PopupMenu = Global.top_menu_container.edit_menu
	edit_menu_popup.set_item_disabled(Global.EditMenu.NEW_BRUSH, !has_selection)

	# We loop through all the reference image nodes and the ones that are not apart
	# of the current project we remove from the tree
	# They will still be in memory though
	for ri: ReferenceImage in Global.canvas.reference_image_container.get_children():
		if !reference_images.has(ri):
			Global.canvas.reference_image_container.remove_child(ri)
	# Now we loop through this projects reference images and add them back to the tree
	var canvas_references := Global.canvas.reference_image_container.get_children()
	for ri: ReferenceImage in reference_images:
		if !canvas_references.has(ri) and !ri.is_inside_tree():
			Global.canvas.reference_image_container.add_child(ri)

	# Tell the reference images that the project changed
	Global.reference_panel.project_changed()

	var i := 0
	for camera in Global.cameras:
		camera.rotation = cameras_rotation[i]
		camera.zoom = cameras_zoom[i]
		camera.offset = cameras_offset[i]
		camera.rotation_changed.emit()
		camera.zoom_changed.emit()
		i += 1


func serialize() -> Dictionary:
	var layer_data := []
	for layer in layers:
		layer_data.append(layer.serialize())
		layer_data[-1]["metadata"] = _serialize_metadata(layer)

	var tag_data := []
	for tag in animation_tags:
		(
			tag_data
			. append(
				{
					"name": tag.name,
					"color": tag.color.to_html(),
					"from": tag.from,
					"to": tag.to,
				}
			)
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
			cel_data.append(cel.serialize())
			cel_data[-1]["metadata"] = _serialize_metadata(cel)

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
		"pxo_version": ProjectSettings.get_setting("application/config/Pxo_Version"),
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

	serialized.emit(project_data)
	return project_data


func deserialize(dict: Dictionary) -> void:
	about_to_deserialize.emit(dict)
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
		for saved_layer in dict.layers:
			match int(saved_layer.get("type", Global.LayerTypes.PIXEL)):
				Global.LayerTypes.PIXEL:
					layers.append(PixelLayer.new(self))
				Global.LayerTypes.GROUP:
					layers.append(GroupLayer.new(self))
				Global.LayerTypes.THREE_D:
					layers.append(Layer3D.new(self))

		var frame_i := 0
		for frame in dict.frames:
			var cels: Array[BaseCel] = []
			var cel_i := 0
			for cel in frame.cels:
				match int(dict.layers[cel_i].get("type", Global.LayerTypes.PIXEL)):
					Global.LayerTypes.PIXEL:
						cels.append(PixelCel.new(Image.new()))
					Global.LayerTypes.GROUP:
						cels.append(GroupCel.new())
					Global.LayerTypes.THREE_D:
						cels.append(Cel3D.new(size, true))
				if dict.has("pxo_version"):
					cel["pxo_version"] = dict["pxo_version"]
				cels[cel_i].deserialize(cel)
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

		# Parent references to other layers are created when deserializing
		# a layer, so loop again after creating them:
		for layer_i in dict.layers.size():
			layers[layer_i].index = layer_i
			layers[layer_i].deserialize(dict.layers[layer_i])
			_deserialize_metadata(layers[layer_i], dict.layers[layer_i])
	if dict.has("tags"):
		for tag in dict.tags:
			animation_tags.append(AnimationTag.new(tag.name, Color(tag.color), tag.from, tag.to))
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
	if dict.has("export_directory_path"):
		directory_path = dict.export_directory_path
	if dict.has("export_file_name"):
		file_name = dict.export_file_name
	if dict.has("export_file_format"):
		file_format = dict.export_file_format
	if dict.has("fps"):
		fps = dict.fps
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
		Global.current_frame_mark_label.text = "%s/%s" % [str(current_frame + 1), frames.size()]

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
		var tag_c: Container = animation_tag_node.instantiate()
		Global.tag_container.add_child(tag_c)
		tag_c.tag = tag
		var tag_position := Global.tag_container.get_child_count() - 1
		Global.tag_container.move_child(tag_c, tag_position)
		tag_c.get_node("Label").text = tag.name
		tag_c.get_node("Label").modulate = tag.color
		tag_c.get_node("Line2D").default_color = tag.color
		tag_c.position = tag.get_position()
		tag_c.custom_minimum_size.x = tag.get_minimum_size()
		tag_c.get_node("Line2D").points[2] = Vector2(tag_c.custom_minimum_size.x, 0)
		tag_c.get_node("Line2D").points[3] = Vector2(tag_c.custom_minimum_size.x, 32)

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


func is_empty() -> bool:
	return (
		frames.size() == 1
		and layers.size() == 1
		and layers[0] is PixelLayer
		and frames[0].cels[0].image.is_invisible()
		and animation_tags.size() == 0
	)


func can_pixel_get_drawn(
	pixel: Vector2i,
	image: SelectionMap = selection_map,
	selection_position: Vector2i = Global.canvas.selection.big_bounding_rectangle.position
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


## Loops through all of the cels until it finds a drawable (non-[GroupCel]) [BaseCel]
## in the specified [param frame] and returns it. If no drawable cel is found,
## meaning that all of the cels are [GroupCel]s, the method returns null.
## If no [param frame] is specified, the method will use the current frame.
func find_first_drawable_cel(frame := frames[current_frame]) -> BaseCel:
	var result: BaseCel
	var cel := frame.cels[0]
	var i := 0
	while cel is GroupCel and i < layers.size():
		cel = frame.cels[i]
		i += 1
	if not cel is GroupCel:
		result = cel
	return result


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
	_update_frame_ui()


func remove_frames(indices: Array) -> void:  # indices should be in ascending order
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	for i in indices.size():
		# With each removed index, future indices need to be lowered, so subtract by i
		# For each linked cel in the frame, update its layer's cel_link_sets
		for l in layers.size():
			var cel: BaseCel = frames[indices[i] - i].cels[l]
			cel.on_remove()
			if cel.link_set != null:
				cel.link_set["cels"].erase(cel)
				if cel.link_set["cels"].is_empty():
					layers[l].cel_link_sets.erase(cel.link_set)
		# Remove frame
		frames.remove_at(indices[i] - i)
		Global.animation_timeline.project_frame_removed(indices[i] - i)
	_update_frame_ui()


func move_frame(from_index: int, to_index: int) -> void:
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	var frame := frames[from_index]
	frames.remove_at(from_index)
	Global.animation_timeline.project_frame_removed(from_index)
	frames.insert(to_index, frame)
	Global.animation_timeline.project_frame_added(to_index)
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


func reverse_frames(frame_indices: Array) -> void:
	Global.canvas.selection.transform_content_confirm()
	for i in frame_indices.size() / 2:
		var index: int = frame_indices[i]
		var reverse_index: int = frame_indices[-i - 1]
		var temp := frames[index]
		frames[index] = frames[reverse_index]
		frames[reverse_index] = temp
		Global.animation_timeline.project_frame_removed(index)
		Global.animation_timeline.project_frame_added(index)
		Global.animation_timeline.project_frame_removed(reverse_index)
		Global.animation_timeline.project_frame_added(reverse_index)
	_set_timeline_first_and_last_frames()
	change_cel(-1)


func add_layers(new_layers: Array, indices: Array, cels: Array) -> void:  # cels is 2d Array of cels
	Global.canvas.selection.transform_content_confirm()
	selected_cels.clear()
	for i in indices.size():
		layers.insert(indices[i], new_layers[i])
		for f in frames.size():
			frames[f].cels.insert(indices[i], cels[i][f])
		new_layers[i].project = self
		Global.animation_timeline.project_layer_added(indices[i])
	_update_layer_ui()


func remove_layers(indices: Array) -> void:
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


## Update the layer indices and layer/cel buttons
func _update_layer_ui() -> void:
	for l in layers.size():
		layers[l].index = l
		Global.layer_vbox.get_child(layers.size() - 1 - l).layer_index = l
		var cel_hbox: HBoxContainer = Global.cel_vbox.get_child(layers.size() - 1 - l)
		for f in frames.size():
			cel_hbox.get_child(f).layer = l
			cel_hbox.get_child(f).button_setup()


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
