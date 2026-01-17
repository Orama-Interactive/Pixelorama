class_name BaseTool
extends VBoxContainer

var is_moving := false
var is_syncing := false
var kname: String
var tool_slot: Tools.Slot = null
var cursor_text := ""
var editing_3d_node: Node3D
var materials_3d: Dictionary[BaseMaterial3D, Image]  ## Used for drawing on 3D models.
var _cursor := Vector2i(Vector2.INF)
var _stabilizer_center := Vector2.ZERO

var _draw_cache: Array[Vector2i] = []  ## For storing already drawn pixels
@warning_ignore("unused_private_class_variable")
var _for_frame := 0  ## Cache for which frame

# Only use _spacing_mode and _spacing variables (the others are set automatically)
# The _spacing_mode and _spacing values are to be CHANGED only in the tool scripts (e.g Pencil.gd)
var _spacing_mode := false  ## Enables spacing (continuous gaps between two strokes)
var _spacing := Vector2i.ZERO  ## Spacing between two strokes
var _stroke_dimensions := Vector2i.ONE  ## 2D vector containing _brush_size from Draw.gd
var _spacing_offset := Vector2i.ZERO  ## The initial error between position and position.snapped()
@onready var color_rect := $ColorRect as ColorRect


func _ready() -> void:
	kname = name.replace(" ", "_").to_lower()
	if tool_slot.name == "Left tool":
		color_rect.color = Global.left_tool_color
	else:
		color_rect.color = Global.right_tool_color
	$Label.text = Tools.tools[name].display_name
	load_config()


func save_config() -> void:
	var config := get_config()
	Global.config_cache.set_value(tool_slot.kname, kname, config)
	if not is_syncing:  # If the tool isn't busy syncing with another tool.
		Tools.config_changed.emit(tool_slot.button, config)


func load_config() -> void:
	var value = Global.config_cache.get_value(tool_slot.kname, kname, {})
	set_config(value)
	update_config()


func get_config() -> Dictionary:
	return {}


func set_config(_config: Dictionary) -> void:
	pass


func update_config() -> void:
	pass


func draw_start(pos: Vector2i) -> void:
	_stabilizer_center = pos
	_draw_cache = []
	is_moving = true
	Global.current_project.can_undo = false
	_spacing_offset = _get_spacing_offset(pos)


func draw_move(pos: Vector2i) -> void:
	# This can happen if the user switches between tools with a shortcut
	# while using another tool
	if !is_moving:
		draw_start(pos)


func draw_end(_pos: Vector2i) -> void:
	is_moving = false
	_draw_cache = []
	var project := Global.current_project
	project.can_undo = true


func cancel_tool() -> void:
	is_moving = false
	_draw_cache = []
	Global.current_project.can_undo = true


func get_cell_position(pos: Vector2i) -> Vector2i:
	var tile_pos := Vector2i.ZERO
	if Global.current_project.get_current_cel() is not CelTileMap:
		return tile_pos
	var cel := Global.current_project.get_current_cel() as CelTileMap
	tile_pos = cel.get_cell_position(pos)
	return tile_pos


func cursor_move(pos: Vector2i) -> void:
	_cursor = pos
	if _spacing_mode and is_moving:
		_cursor = get_spacing_position(pos)


func get_spacing_position(pos: Vector2i) -> Vector2i:
	# spacing_factor is the distance the mouse needs to get snapped by in order
	# to keep a space "_spacing" between two strokes of dimensions "_stroke_dimensions"
	var spacing_factor := _stroke_dimensions + _spacing
	var snap_pos := Vector2(pos.snapped(spacing_factor) + _spacing_offset)

	# keeping snap_pos as is would have been fine but this adds extra accuracy as to
	# which snap point (from the list below) is closest to mouse and occupy THAT point
	var t_l := snap_pos + Vector2(-spacing_factor.x, -spacing_factor.y)
	var t_c := snap_pos + Vector2(0, -spacing_factor.y)  # t_c is for "top centre" and so on...
	var t_r := snap_pos + Vector2(spacing_factor.x, -spacing_factor.y)
	var m_l := snap_pos + Vector2(-spacing_factor.x, 0)
	var m_c := snap_pos
	var m_r := snap_pos + Vector2(spacing_factor.x, 0)
	var b_l := snap_pos + Vector2(-spacing_factor.x, spacing_factor.y)
	var b_c := snap_pos + Vector2(0, spacing_factor.y)
	var b_r := snap_pos + Vector2(spacing_factor.x, spacing_factor.y)
	var vec_arr: PackedVector2Array = [t_l, t_c, t_r, m_l, m_c, m_r, b_l, b_c, b_r]
	for vec in vec_arr:
		if vec.distance_to(pos) < snap_pos.distance_to(pos):
			snap_pos = vec

	return Vector2i(snap_pos)


func _get_spacing_offset(pos: Vector2i) -> Vector2i:
	var spacing_factor := _stroke_dimensions + _spacing  # spacing_factor is explained above
	# since we just started drawing, the "position" is our intended location so the error
	# (_spacing_offset) is measured by subtracting both quantities
	return pos - pos.snapped(spacing_factor)


func draw_indicator(left: bool) -> void:
	var rect := Rect2(_cursor, Vector2.ONE)
	var color := Global.left_tool_color if left else Global.right_tool_color
	Global.canvas.indicators.draw_rect(rect, color, false)


func draw_preview() -> void:
	pass


func snap_position(pos: Vector2) -> Vector2:
	var snapping_distance := Global.snapping_distance / Global.camera.zoom.x
	if Global.snap_to_rectangular_grid_boundary:
		pos = Tools.snap_to_rectangular_grid_boundary(
			pos, Global.grids[0].grid_size, Global.grids[0].grid_offset, snapping_distance
		)

	if Global.snap_to_rectangular_grid_center:
		pos = Tools.snap_to_rectangular_grid_center(
			pos, Global.grids[0].grid_size, Global.grids[0].grid_offset, snapping_distance
		)

	var snap_to := Vector2.INF
	if Global.snap_to_guides:
		for guide in Global.current_project.guides:
			if guide is SymmetryGuide:
				continue
			var s1: Vector2 = guide.points[0]
			var s2: Vector2 = guide.points[1]
			var snap := Tools.snap_to_guide(snap_to, pos, snapping_distance, s1, s2)
			if snap == Vector2.INF:
				continue
			snap_to = snap

	if Global.snap_to_perspective_guides:
		for point in Global.current_project.vanishing_points:
			if not (point.has("pos_x") and point.has("pos_y")):  # Sanity check
				continue
			for i in point.lines.size():
				if point.lines[i].has("angle") and point.lines[i].has("length"):  # Sanity check
					var angle := deg_to_rad(point.lines[i].angle)
					var length: float = point.lines[i].length
					var start := Vector2(point.pos_x, point.pos_y)
					var s1 := start
					var s2 := s1 + Vector2(length * cos(angle), length * sin(angle))
					var snap := Tools.snap_to_guide(snap_to, pos, snapping_distance, s1, s2)
					if snap == Vector2.INF:
						continue
					snap_to = snap
	if snap_to != Vector2.INF:
		pos = snap_to.floor()

	return pos


## Returns an array that mirrors each point of the [param array].
## An optional [param callable] can be passed, which gets called for each type of symmetry.
func mirror_array(array: Array[Vector2i], callable := func(_array): pass) -> Array[Vector2i]:
	var new_array: Array[Vector2i] = []
	var project := Global.current_project
	if Tools.horizontal_mirror and Tools.vertical_mirror:
		var hv_array: Array[Vector2i] = []
		for point in array:
			var mirror_x := Tools.calculate_mirror_horizontal(point, project)
			hv_array.append(Tools.calculate_mirror_vertical(mirror_x, project))
		if callable.is_valid():
			callable.call(hv_array)
		new_array += hv_array
	if Tools.horizontal_mirror:
		var h_array: Array[Vector2i] = []
		for point in array:
			h_array.append(Tools.calculate_mirror_horizontal(point, project))
		if callable.is_valid():
			callable.call(h_array)
		new_array += h_array
	if Tools.vertical_mirror:
		var v_array: Array[Vector2i] = []
		for point in array:
			v_array.append(Tools.calculate_mirror_vertical(point, project))
		if callable.is_valid():
			callable.call(v_array)
		new_array += v_array

	return new_array


func get_3d_node_at_pos(pos: Vector2i, camera: Camera3D, max_distance := 100.0) -> Array:
	var scenario := camera.get_world_3d().scenario
	var ray_from := camera.project_ray_origin(pos)
	var ray_dir := camera.project_ray_normal(pos)
	var ray_to := ray_from + ray_dir * max_distance
	var intersecting_objects := RenderingServer.instances_cull_ray(ray_from, ray_to, scenario)
	for obj in intersecting_objects:
		var intersect_node := instance_from_id(obj)
		if intersect_node is not Node3D:
			continue
		# Convert ray into the node’s local space
		var to_local := (intersect_node as Node3D).global_transform.affine_inverse()
		var local_from := to_local * ray_from
		var local_to := to_local * ray_to
		if not intersect_node is MeshInstance3D:
			continue
		var mesh_instance := intersect_node as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		var closest_dist := INF
		var best_hit := {}
		var best_surface := -1
		for surface_idx in range(mesh.get_surface_count()):
			var surface := mesh.surface_get_arrays(surface_idx)
			if surface.is_empty():
				continue

			var vertices: PackedVector3Array = []
			if surface[Mesh.ARRAY_VERTEX]:
				vertices = surface[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = []
			if surface[Mesh.ARRAY_INDEX]:
				indices = surface[Mesh.ARRAY_INDEX]

			if indices.is_empty():
				# non-indexed: vertices are already triangles
				for i in range(0, vertices.size(), 3):
					var hit = Geometry3D.ray_intersects_triangle(
						local_from,
						local_to - local_from,
						vertices[i],
						vertices[i + 1],
						vertices[i + 2]
					)
					if hit:
						var d := local_from.distance_to(hit)
						if d < closest_dist:
							closest_dist = d
							@warning_ignore("integer_division")
							best_hit = {"position": hit, "face_index": i / 3}
							best_surface = surface_idx
			else:
				for i in range(0, indices.size(), 3):
					var v0 := vertices[indices[i]]
					var v1 := vertices[indices[i + 1]]
					var v2 := vertices[indices[i + 2]]
					var hit = Geometry3D.ray_intersects_triangle(
						local_from, local_to - local_from, v0, v1, v2
					)
					if hit:
						var d := local_from.distance_to(hit)
						if d < closest_dist:
							closest_dist = d
							@warning_ignore("integer_division")
							best_hit = {"position": hit, "face_index": i / 3}
							best_surface = surface_idx

		if best_surface == -1:
			return []
		return [intersect_node, best_hit, best_surface]
	return []


# Inspired from
# https://github.com/BastiaanOlij/drawable-textures-demo/blob/master/main.gd
func get_3d_node_uvs(pos: Vector2i, camera: Camera3D, max_distance := 100.0) -> Array:
	var intersect_data := get_3d_node_at_pos(pos, camera, max_distance)
	if intersect_data.is_empty():
		return []
	var object := intersect_data[0] as MeshInstance3D
	var intersect_result := intersect_data[1] as Dictionary
	var surface_index := intersect_data[2] as int
	var faces: PackedVector3Array
	var uvs: PackedVector2Array
	var surface := object.mesh.surface_get_arrays(surface_index)
	var vertices: PackedVector3Array = surface[Mesh.ARRAY_VERTEX]
	var tex_uvs: PackedVector2Array
	if surface[Mesh.ARRAY_TEX_UV] == null:
		for v in vertices:
			tex_uvs.append(Vector2(v.x, v.z))  # XZ projection fallback
	else:
		tex_uvs = surface[Mesh.ARRAY_TEX_UV]
	if surface[Mesh.ARRAY_INDEX] != null:
		var indices: PackedInt32Array = surface[Mesh.ARRAY_INDEX]
		var index_count := indices.size()
		uvs.resize(index_count)
		faces.resize(index_count)
		for index in range(index_count):
			var vertex_idx := indices[index]
			uvs[index] = tex_uvs[vertex_idx]
			faces[index] = vertices[vertex_idx]
	else:
		var index_count := vertices.size()
		uvs.resize(index_count)
		faces.resize(index_count)
		for index in range(index_count):
			uvs[index] = tex_uvs[index]
			faces[index] = vertices[index]

	var index: int = intersect_result.face_index * 3
	var f: Vector3 = intersect_result.position
	if index + 2 >= faces.size():
		return []
	var p1 := faces[index]
	var p2 := faces[index + 1]
	var p3 := faces[index + 2]

	# calculate vectors from point f to vertices p1, p2 and p3:
	var f1 := p1 - f
	var f2 := p2 - f
	var f3 := p3 - f

	# calculate the areas and factors (order of parameters doesn't matter):
	var a: float = (p1 - p2).cross(p1 - p3).length()  # main triangle area a
	var a1: float = f2.cross(f3).length() / a  # p1's triangle area / a
	var a2: float = f3.cross(f1).length() / a  # p2's triangle area / a
	var a3: float = f1.cross(f2).length() / a  # p3's triangle area / a

	# find the uv corresponding to point f (uv1/uv2/uv3 are associated to p1/p2/p3):
	var uv: Vector2 = uvs[index] * a1 + uvs[index + 1] * a2 + uvs[index + 2] * a3

	return [object, uv, surface_index]


func _get_stabilized_position(normal_pos: Vector2) -> Vector2:
	if not Tools.stabilizer_enabled:
		return normal_pos
	var difference := normal_pos - _stabilizer_center
	var distance := difference.length() / Tools.stabilizer_value
	var angle := difference.angle()
	var pos := _stabilizer_center + Vector2(distance, distance) * Vector2.from_angle(angle)
	_stabilizer_center = pos
	return pos


func _get_draw_rect() -> Rect2i:
	if Global.current_project.has_selection:
		return Global.current_project.selection_map.get_used_rect()
	else:
		return Rect2i(Vector2i.ZERO, Global.current_project.size)


func _get_draw_image() -> ImageExtended:
	return Global.current_project.get_current_cel().get_image()


func _get_selected_draw_cels() -> Array[BaseCel]:
	var cels: Array[BaseCel]
	var project := Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if not cel is PixelCel:
			continue
		cels.append(cel)
	return cels


func _get_selected_draw_images() -> Array[ImageExtended]:
	var images: Array[ImageExtended] = []
	if not materials_3d.is_empty():
		for mat in materials_3d:
			if is_instance_valid(mat.albedo_texture):
				var temp_image := mat.albedo_texture.get_image()
				var image := ImageExtended.new()
				image.copy_from_custom(temp_image)
				images.append(image)
		return images
	var project := Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if not cel is PixelCel:
			continue
		if project.layers[cel_index[1]].can_layer_get_drawn():
			images.append(cel.get_image())
	return images


func _pick_color(pos: Vector2i) -> void:
	var project := Global.current_project
	pos = project.tiles.get_canon_position(pos)

	if pos.x < 0 or pos.y < 0:
		return
	if Tools.is_placing_tiles():
		var cel := Global.current_project.get_current_cel() as CelTileMap
		Tools.selected_tile_index_changed.emit(cel.get_cell_index_at_coords(pos))
		return
	var image := Image.new()
	image.copy_from(_get_draw_image())
	if pos.x > image.get_width() - 1 or pos.y > image.get_height() - 1:
		return

	var color := Color(0, 0, 0, 0)
	var palette_index = -1
	var curr_frame: Frame = project.frames[project.current_frame]
	for layer in project.layers.size():
		var idx := (project.layers.size() - 1) - layer
		if project.layers[idx].is_visible_in_hierarchy():
			var cel := curr_frame.cels[idx]
			image = cel.get_image()
			color = image.get_pixelv(pos)
			# If image is indexed then get index as well
			if cel is PixelCel:
				if cel.image.is_indexed:
					palette_index = cel.image.indices_image.get_pixel(pos.x, pos.y).r8 - 1
			if not is_zero_approx(color.a) or palette_index > -1:
				break
	Tools.assign_color(color, tool_slot.button, false, palette_index)


func _flip_rect(rect: Rect2, rect_size: Vector2, horiz: bool, vert: bool) -> Rect2:
	var result := rect
	if horiz:
		result.position.x = rect_size.x - rect.end.x
		result.end.x = rect_size.x - rect.position.x
	if vert:
		result.position.y = rect_size.y - rect.end.y
		result.end.y = rect_size.y - rect.position.y
	return result.abs()


func _create_polylines(bitmap: BitMap) -> Array:
	var lines := []
	var bitmap_size := bitmap.get_size()
	for y in bitmap_size.y:
		for x in bitmap_size.x:
			var p := Vector2i(x, y)
			if not bitmap.get_bitv(p):
				continue
			if x <= 0 or not bitmap.get_bitv(p - Vector2i(1, 0)):
				_add_polylines_segment(lines, p, p + Vector2i(0, 1))
			if y <= 0 or not bitmap.get_bitv(p - Vector2i(0, 1)):
				_add_polylines_segment(lines, p, p + Vector2i(1, 0))
			if x + 1 >= bitmap_size.x or not bitmap.get_bitv(p + Vector2i(1, 0)):
				_add_polylines_segment(lines, p + Vector2i(1, 0), p + Vector2i(1, 1))
			if y + 1 >= bitmap_size.y or not bitmap.get_bitv(p + Vector2i(0, 1)):
				_add_polylines_segment(lines, p + Vector2i(0, 1), p + Vector2i(1, 1))
	return lines


func _fill_bitmap_with_points(points: Array[Vector2i], bitmap_size: Vector2i) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create(bitmap_size)

	for point in points:
		if point.x < 0 or point.y < 0 or point.x >= bitmap_size.x or point.y >= bitmap_size.y:
			continue
		bitmap.set_bitv(point, 1)

	return bitmap


func _add_polylines_segment(lines: Array, start: Vector2i, end: Vector2i) -> void:
	for line in lines:
		if line[0] == start:
			line.insert(0, end)
			return
		if line[0] == end:
			line.insert(0, start)
			return
		if line[line.size() - 1] == start:
			line.append(end)
			return
		if line[line.size() - 1] == end:
			line.append(start)
			return
	lines.append([start, end])


func _exit_tree() -> void:
	if is_moving:
		draw_end(Global.canvas.current_pixel.floor())
	Global.canvas.previews_sprite.texture = null
	Global.canvas.indicators.queue_redraw()
