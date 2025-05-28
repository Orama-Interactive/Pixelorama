class_name SelectionNode
extends Node2D

signal transformation_confirmed
signal transformation_canceled

enum SelectionOperation { ADD, SUBTRACT, INTERSECT }
const CLIPBOARD_FILE_PATH := "user://clipboard.txt"

# flags (additional properties of selection that can be toggled)
var flag_tilemode := false

var undo_data: Dictionary
var is_pasting := false

var preview_selection_map := SelectionMap.new()
var preview_selection_texture := ImageTexture.new()

@onready var canvas := get_parent() as Canvas
@onready var transformation_handles := $TransformationHandles as TransformationHandles
@onready var marching_ants_outline := $MarchingAntsOutline as Sprite2D


func _ready() -> void:
	marching_ants_outline.texture = preview_selection_texture
	transformation_handles.preview_transform_changed.connect(_update_marching_ants)
	Global.project_switched.connect(_project_switched)
	Global.camera.zoom_changed.connect(_update_on_zoom)


func _input(event: InputEvent) -> void:
	if transformation_handles.is_transforming_content():
		if event.is_action_pressed(&"transformation_confirm"):
			transform_content_confirm()
		elif event.is_action_pressed(&"transformation_cancel"):
			transform_content_cancel()


func _draw() -> void:
	transformation_handles.queue_redraw()


func _update_on_zoom() -> void:
	var zoom := Global.camera.zoom.x
	var size := maxi(
		Global.current_project.selection_map.get_size().x,
		Global.current_project.selection_map.get_size().y
	)
	marching_ants_outline.material.set_shader_parameter("width", 1.0 / zoom)
	marching_ants_outline.material.set_shader_parameter("frequency", zoom * 10 * size / 64)


func select_rect(rect: Rect2i, operation := SelectionOperation.ADD) -> void:
	var project := Global.current_project
	# Used only if the selection is outside of the canvas boundaries,
	# on the left and/or above (negative coords)
	var offset_position := Vector2i.ZERO
	if project.selection_offset.x < 0:
		rect.position.x -= project.selection_offset.x
		offset_position.x = project.selection_offset.x
	if project.selection_offset.y < 0:
		rect.position.y -= project.selection_offset.y
		offset_position.y = project.selection_offset.y

	if offset_position != Vector2i.ZERO:
		project.selection_map.move_bitmap_values(project)

	if operation == SelectionOperation.ADD:
		project.selection_map.fill_rect(rect, Color(1, 1, 1, 1))
	elif operation == SelectionOperation.SUBTRACT:
		project.selection_map.fill_rect(rect, Color(0))
	elif operation == SelectionOperation.INTERSECT:
		var previous_selection_map := SelectionMap.new()
		previous_selection_map.copy_from(project.selection_map)
		project.selection_map.clear()
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var pos := Vector2i(x, y)
				if !Rect2i(Vector2i.ZERO, previous_selection_map.get_size()).has_point(pos):
					continue
				project.selection_map.select_pixel(
					pos, previous_selection_map.is_pixel_selected(pos, false)
				)

	if offset_position != Vector2i.ZERO and project.has_selection:
		project.selection_map.move_bitmap_values(project)


func transform_content_confirm() -> void:
	if not transformation_handles.is_transforming_content():
		return
	var project := Global.current_project
	var preview_image := transformation_handles.pre_transformed_image
	transformation_handles.bake_transform_to_selection(project.selection_map)
	var selection_rect := project.selection_map.get_selection_rect(project)
	var selection_size_rect := Rect2i(Vector2i.ZERO, selection_rect.size)
	for cel in get_selected_draw_cels():
		var cel_image := cel.get_image()
		var src := Image.new()
		src.copy_from(preview_image)
		if not is_pasting:
			if not is_instance_valid(cel.transformed_content):
				continue
			src.copy_from(cel.transformed_content)
			cel.transformed_content = null
		var transformation_origin := transformation_handles.get_transform_top_left(src.get_size())
		if Tools.is_placing_tiles():
			if cel is not CelTileMap:
				continue
			var tilemap := cel as CelTileMap
			@warning_ignore("integer_division")
			var horizontal_size := selection_rect.size.x / tilemap.get_tile_size().x
			@warning_ignore("integer_division")
			var vertical_size := selection_rect.size.y / tilemap.get_tile_size().y
			var selected_cells := tilemap.resize_selection(
				transformation_handles.pre_transform_tilemap_cells, horizontal_size, vertical_size
			)
			src.crop(selection_rect.size.x, selection_rect.size.y)
			tilemap.apply_resizing_to_image(src, selected_cells, selection_rect, true)
		else:
			transformation_handles.bake_transform_to_image(src, selection_size_rect)

		if Tools.is_placing_tiles():
			if cel.get_tile_shape() != TileSet.TILE_SHAPE_SQUARE:
				continue
			cel_image.blit_rect(src, selection_size_rect, transformation_origin)
		else:
			cel_image.blit_rect_mask(src, src, selection_size_rect, transformation_origin)
		cel_image.convert_rgb_to_indexed()
	commit_undo("Move Selection", undo_data)

	is_pasting = false
	queue_redraw()
	canvas.queue_redraw()
	transformation_confirmed.emit()


func transform_content_cancel() -> void:
	if not transformation_handles.is_transforming_content():
		return
	var project := Global.current_project
	project.selection_offset = transformation_handles.pre_transform_selection_offset
	project.selection_map_changed()
	for cel in get_selected_draw_cels():
		var cel_image := cel.get_image()
		if !is_pasting:
			cel_image.blit_rect_mask(
				cel.transformed_content,
				cel.transformed_content,
				Rect2i(Vector2i.ZERO, Global.current_project.selection_map.get_size()),
				project.selection_map.get_selection_rect(project).position
			)
			cel.transformed_content = null
	for cel_index in project.selected_cels:
		canvas.update_texture(cel_index[1])
	is_pasting = false
	queue_redraw()
	canvas.queue_redraw()
	transformation_canceled.emit()


func commit_undo(action: String, undo_data_tmp: Dictionary) -> void:
	if !undo_data_tmp:
		print("No undo data found!")
		return
	var project := Global.current_project
	if Tools.is_placing_tiles():
		for cel in undo_data_tmp:
			if cel is CelTileMap:
				(cel as CelTileMap).re_index_all_cells(true)
	else:
		project.update_tilemaps(undo_data_tmp, TileSetPanel.TileEditingMode.AUTO)
	var redo_data := get_undo_data(undo_data_tmp["undo_image"])
	project.undos += 1
	project.undo_redo.create_action(action)
	project.deserialize_cel_undo_data(redo_data, undo_data_tmp)
	project.undo_redo.add_do_property(project, "selection_offset", redo_data["outline_offset"])

	project.undo_redo.add_undo_property(
		project, "selection_offset", undo_data_tmp["outline_offset"]
	)

	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_do_method(project.selection_map_changed)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_undo_method(project.selection_map_changed)
	project.undo_redo.commit_action()

	undo_data.clear()


func get_undo_data(undo_image: bool) -> Dictionary:
	var data := {}
	var project := Global.current_project
	data[project.selection_map] = project.selection_map.data
	data["outline_offset"] = Global.current_project.selection_offset
	data["undo_image"] = undo_image

	if undo_image:
		Global.current_project.serialize_cel_undo_data(get_selected_draw_cels(), data)
	return data


func _update_marching_ants() -> void:
	preview_selection_map.copy_from(Global.current_project.selection_map)
	if is_instance_valid(transformation_handles.transformed_selection_map):
		transformation_handles.bake_transform_to_selection(preview_selection_map)
	preview_selection_texture.set_image(preview_selection_map)


# TODO: Change BaseCel to PixelCel if Godot ever fixes issues
# with typed arrays being cast into other types.
func get_selected_draw_cels() -> Array[BaseCel]:
	var cels: Array[BaseCel] = []
	var project := Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if not cel is PixelCel:
			continue
		if project.layers[cel_index[1]].can_layer_get_drawn():
			cels.append(cel)
	return cels


func _get_selected_draw_images(tile_cel_pointer: Array[CelTileMap]) -> Array[ImageExtended]:
	var images: Array[ImageExtended] = []
	var project := Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if not cel is PixelCel:
			continue
		if cel is CelTileMap and Tools.is_placing_tiles():
			tile_cel_pointer.append(cel)
			continue
		if project.layers[cel_index[1]].can_layer_get_drawn():
			images.append(cel.get_image())
	return images


## Returns the portion of current cel's image enclosed by the selection.
func get_enclosed_image() -> Image:
	var project := Global.current_project
	if !project.has_selection:
		return

	var image := project.get_current_cel().get_image()
	var enclosed_img := Image.new()
	if transformation_handles.is_transforming_content():
		enclosed_img.copy_from(transformation_handles.transformed_image)
	else:
		enclosed_img = get_selected_image(image)
	return enclosed_img


func cut() -> void:
	var project := Global.current_project
	if !project.layers[project.current_layer].can_layer_get_drawn():
		return
	copy()
	delete(false)


## Copies the selection content (works in or between pixelorama instances only).
func copy() -> void:
	var project := Global.current_project
	var cl_image := Image.new()
	var cl_selection_map := SelectionMap.new()
	var cl_big_bounding_rectangle := Rect2()
	var cl_selection_offset := Vector2.ZERO

	var image := project.get_current_cel().get_image()
	var to_copy := Image.new()
	if !project.has_selection:
		to_copy.copy_from(image)
		cl_selection_map.copy_from(project.selection_map)
		cl_selection_map.select_all()
		cl_big_bounding_rectangle = Rect2(Vector2.ZERO, project.size)
	else:
		var selection_rect := project.selection_map.get_selection_rect(project)
		if transformation_handles.is_transforming_content():
			to_copy.copy_from(transformation_handles.transformed_image)
			cl_selection_map = preview_selection_map
		else:
			to_copy = image.get_region(selection_rect)
			# Remove unincluded pixels if the selection is not a single rectangle
			var offset_pos := selection_rect.position
			for x in to_copy.get_size().x:
				for y in to_copy.get_size().y:
					var pos := Vector2i(x, y)
					if offset_pos.x < 0:
						offset_pos.x = 0
					if offset_pos.y < 0:
						offset_pos.y = 0
					if not project.selection_map.is_pixel_selected(pos + offset_pos, false):
						to_copy.set_pixelv(pos, Color(0))
			cl_selection_map.copy_from(project.selection_map)
		cl_big_bounding_rectangle = selection_rect

	cl_image = to_copy
	cl_selection_offset = project.selection_offset
	var transfer_clipboard := {
		"image": cl_image,
		"selection_map": cl_selection_map.data,
		"big_bounding_rectangle": cl_big_bounding_rectangle,
		"selection_offset": cl_selection_offset,
	}

	var clipboard_file := FileAccess.open(CLIPBOARD_FILE_PATH, FileAccess.WRITE)
	clipboard_file.store_var(transfer_clipboard, true)
	clipboard_file.close()

	if !to_copy.is_empty():
		var pattern: Patterns.Pattern = Global.patterns_popup.get_pattern(0)
		pattern.image = to_copy
		var tex := ImageTexture.create_from_image(to_copy)
		var container = Global.patterns_popup.get_node("ScrollContainer/PatternContainer")
		container.get_child(0).get_child(0).texture = tex


## Pastes the selection content.
func paste(in_place := false) -> void:
	if !FileAccess.file_exists(CLIPBOARD_FILE_PATH):
		return
	var clipboard_file := FileAccess.open(CLIPBOARD_FILE_PATH, FileAccess.READ)
	var clipboard = clipboard_file.get_var(true)
	clipboard_file.close()

	# Sanity checks
	if typeof(clipboard) != TYPE_DICTIONARY:
		return
	if !clipboard.has_all(["image", "selection_map", "big_bounding_rectangle", "selection_offset"]):
		return
	if clipboard.image.is_empty():
		return

	if transformation_handles.is_transforming_content():
		transform_content_confirm()
	undo_data = get_undo_data(true)
	clear_selection()
	var project := Global.current_project

	var clip_map := SelectionMap.new()
	clip_map.data = clipboard.selection_map
	var max_size := Vector2i(
		maxi(clip_map.get_size().x, project.selection_map.get_size().x),
		maxi(clip_map.get_size().y, project.selection_map.get_size().y)
	)

	project.selection_map.copy_from(clip_map)
	project.selection_map.crop(max_size.x, max_size.y)
	var selection_rect := project.selection_map.get_selection_rect(project)
	project.selection_offset = clipboard.selection_offset
	var transform_origin: Vector2 = clipboard.big_bounding_rectangle.position
	if not in_place:  # If "Paste" is selected, and not "Paste in Place"
		var camera_center := Global.camera.camera_screen_center
		camera_center -= Vector2(selection_rect.size) / 2.0
		var max_pos := project.size - selection_rect.size
		if max_pos.x >= 0:
			camera_center.x = clampf(camera_center.x, 0, max_pos.x)
		else:
			camera_center.x = 0
		if max_pos.y >= 0:
			camera_center.y = clampf(camera_center.y, 0, max_pos.y)
		else:
			camera_center.y = 0
		transform_origin = Vector2i(camera_center.floor())
		if Tools.is_placing_tiles():
			var tilemap_cel := Global.current_project.get_current_cel() as CelTileMap
			var grid_size := tilemap_cel.get_tile_size()
			transform_origin = Vector2i(
				Tools.snap_to_rectangular_grid_boundary(transform_origin, grid_size)
			)
		project.selection_map.move_bitmap_values(Global.current_project, false)
	else:
		if Tools.is_placing_tiles():
			var tilemap_cel := Global.current_project.get_current_cel() as CelTileMap
			var grid_size := tilemap_cel.get_tile_size()
			project.selection_offset = Tools.snap_to_rectangular_grid_boundary(
				project.selection_offset, grid_size
			)
			transform_origin = Vector2i(
				Tools.snap_to_rectangular_grid_boundary(transform_origin, grid_size)
			)

	is_pasting = true
	project.selection_map_changed()
	transformation_handles.begin_transform(clipboard.image)
	transformation_handles.preview_transform.origin = transform_origin


func paste_from_clipboard() -> void:
	if not DisplayServer.clipboard_has_image():
		return
	var clipboard_image := DisplayServer.clipboard_get_image()
	if clipboard_image.is_empty() or clipboard_image.is_invisible():
		return
	if transformation_handles.is_transforming_content():
		transform_content_confirm()
	undo_data = get_undo_data(true)
	clear_selection()
	var project := Global.current_project
	clipboard_image.convert(project.get_image_format())
	var clip_map := SelectionMap.new()
	clip_map.copy_from(
		Image.create(
			clipboard_image.get_width(),
			clipboard_image.get_height(),
			false,
			project.selection_map.get_format()
		)
	)
	clip_map.fill_rect(Rect2i(Vector2i.ZERO, clipboard_image.get_size()), Color(1, 1, 1, 1))
	var max_size := Vector2i(
		maxi(clip_map.get_size().x, project.selection_map.get_size().x),
		maxi(clip_map.get_size().y, project.selection_map.get_size().y)
	)

	project.selection_map.copy_from(clip_map)
	project.selection_map.crop(max_size.x, max_size.y)
	project.selection_map_changed()
	transformation_handles.begin_transform(clipboard_image)
	is_pasting = true


## Deletes the drawing enclosed within the selection's area.
func delete(selected_cels := true) -> void:
	var project := Global.current_project
	if !project.layers[project.current_layer].can_layer_get_drawn():
		return
	if transformation_handles.is_transforming_content():
		if (
			transformation_handles.transformed_image.is_empty()
			or transformation_handles.transformed_image.is_invisible()
		):
			transform_content_confirm()
		else:
			transformation_handles.reset_transform()
			clear_selection()
			transformation_handles.set_selection(null, Rect2())
			is_pasting = false
			queue_redraw()
			commit_undo("Draw", undo_data)
			return

	var undo_data_tmp := get_undo_data(true)
	var images: Array[ImageExtended]
	var tile_cels: Array[CelTileMap]
	if selected_cels:
		images = _get_selected_draw_images(tile_cels)
	else:
		images = [project.get_current_cel().get_image()]
		if project.get_current_cel() is CelTileMap:
			if Tools.is_placing_tiles():
				images.clear()
				tile_cels.append(project.get_current_cel())

	if project.has_selection:
		var blank := project.new_empty_image()
		var selection_map_copy := project.selection_map.return_cropped_copy(project, project.size)
		var selection_rect := selection_map_copy.get_used_rect()
		for image in images:
			image.blit_rect_mask(blank, selection_map_copy, selection_rect, selection_rect.position)
			image.convert_rgb_to_indexed()
		var selection = project.selection_map.get_used_rect()
		for tile_cel: CelTileMap in tile_cels:
			var row := 0
			for y in range(
				selection.position.y,
				selection.end.y,
				floori(tile_cel.tile_size.y / 2.0)
			):
				var current_offset := floori(tile_cel.tile_size.x / 2.0) if row % 2 != 0 else 0
				for x in range(
					selection.position.x + current_offset,
					selection.end.x,
					tile_cel.tile_size.x
				):
					var point = Vector2i(x, y) + Vector2i((Vector2(tile_cel.tile_size) / 2).ceil())
					if selection.has_point(point):
						var tile_position := tile_cel.get_cell_position(point)
						var cell := tile_cel.get_cell_at(tile_position)
						tile_cel.set_index(cell, 0)
						tile_cel.update_tilemap()
				row += 1
	else:
		for image in images:
			image.fill(0)
			image.convert_rgb_to_indexed()
	clear_selection()
	commit_undo("Draw", undo_data_tmp)


## Makes a project brush out of the current selection's content.
func new_brush() -> void:
	var brush := get_enclosed_image()
	if brush and !brush.is_invisible():
		var brush_used: Image = brush.get_region(brush.get_used_rect())
		Global.current_project.brushes.append(brush_used)
		Brushes.add_project_brush(brush_used)


## Select the entire region of current cel.
func select_all() -> void:
	var undo_data_tmp := get_undo_data(false)
	clear_selection()
	var full_rect := Rect2i(Vector2i.ZERO, Global.current_project.size)
	select_rect(full_rect)
	commit_undo("Select", undo_data_tmp)


## Inverts the selection.
func invert() -> void:
	transform_content_confirm()
	var project := Global.current_project
	var undo_data_tmp := get_undo_data(false)
	project.selection_map.crop(project.size.x, project.size.y)
	project.selection_map.invert()
	project.selection_map_changed()
	project.selection_offset = Vector2.ZERO
	commit_undo("Select", undo_data_tmp)


## Clears the selection.
func clear_selection(use_undo := false) -> void:
	var project := Global.current_project
	if !project.has_selection:
		return
	transform_content_confirm()
	var undo_data_tmp := get_undo_data(false)
	project.selection_map.crop(project.size.x, project.size.y)
	project.selection_map.clear()
	project.selection_offset = Vector2.ZERO
	queue_redraw()
	if use_undo:
		commit_undo("Clear Selection", undo_data_tmp)


func select_cel_rect() -> void:
	transform_content_confirm()
	var project := Global.current_project
	var undo_data_tmp := get_undo_data(false)
	project.selection_map.crop(project.size.x, project.size.y)
	project.selection_map.clear()
	var current_cel := project.get_current_cel()
	var cel_image: Image
	if current_cel is GroupCel:
		var group_layer := project.layers[project.current_layer] as GroupLayer
		cel_image = group_layer.blend_children(project.frames[project.current_frame])
	else:
		cel_image = current_cel.get_image()
	project.selection_map.select_rect(cel_image.get_used_rect())
	project.selection_map_changed()
	project.selection_offset = Vector2.ZERO
	commit_undo("Select", undo_data_tmp)


func select_cel_pixels(layer: BaseLayer, frame: Frame) -> void:
	transform_content_confirm()
	var project := Global.current_project
	var undo_data_tmp := get_undo_data(false)
	project.selection_map.crop(project.size.x, project.size.y)
	project.selection_map.clear()
	var current_cel := frame.cels[layer.index]
	var cel_image: Image
	if current_cel is GroupCel:
		cel_image = (layer as GroupLayer).blend_children(frame)
	else:
		cel_image = current_cel.get_image()
	var selection_format := project.selection_map.get_format()
	project.selection_map.copy_from(cel_image)
	project.selection_map.convert(selection_format)
	project.selection_map_changed()
	project.selection_offset = Vector2.ZERO
	commit_undo("Select", undo_data_tmp)


func _project_switched() -> void:
	marching_ants_outline.offset = Global.current_project.selection_offset
	_update_marching_ants()
	queue_redraw()


func get_selected_image(cel_image: Image) -> Image:
	var project := Global.current_project
	var selection_map_copy := project.selection_map.return_cropped_copy(project, project.size)
	var selection_rect := selection_map_copy.get_used_rect()
	var image := Image.create(
		selection_rect.size.x, selection_rect.size.y, false, project.get_image_format()
	)
	image.blit_rect_mask(cel_image, selection_map_copy, selection_rect, Vector2i.ZERO)
	return image
