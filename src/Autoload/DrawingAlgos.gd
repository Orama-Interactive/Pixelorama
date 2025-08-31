extends Node

enum RotationAlgorithm { ROTXEL_SMEAR, CLEANEDGE, OMNISCALE, NNS, NN, ROTXEL, URD }
enum GradientDirection { TOP, BOTTOM, LEFT, RIGHT }
## Continuation from Image.Interpolation
enum Interpolation { SCALE3X = 5, CLEANEDGE = 6, OMNISCALE = 7 }

const DUMMY_PRE_MUL_ALPHA_SHADER := preload("res://src/Shaders/DummyPreMulAlpha.gdshader")

var blend_layers_shader := preload("res://src/Shaders/BlendLayers.gdshader")
var clean_edge_shader: Shader:
	get:
		if clean_edge_shader == null:
			clean_edge_shader = load("res://src/Shaders/Effects/Rotation/cleanEdge.gdshader")
		return clean_edge_shader
var omniscale_shader: Shader:
	get:
		if omniscale_shader == null:
			omniscale_shader = load("res://src/Shaders/Effects/Rotation/OmniScale.gdshader")
		return omniscale_shader
var clean_edge_shader_premul_alpha: Shader:
	get:
		if clean_edge_shader_premul_alpha == null:
			clean_edge_shader_premul_alpha = clean_edge_shader.duplicate()
			clean_edge_shader_premul_alpha.code = clean_edge_shader.code.replace(
				"unshaded", "unshaded, blend_premul_alpha"
			)
		return clean_edge_shader_premul_alpha
var omniscale_shader_premul_alpha: Shader:
	get:
		if omniscale_shader_premul_alpha == null:
			omniscale_shader_premul_alpha = omniscale_shader.duplicate()
			omniscale_shader_premul_alpha.code = omniscale_shader.code.replace(
				"unshaded", "unshaded, blend_premul_alpha"
			)
		return omniscale_shader_premul_alpha
var rotxel_shader := preload("res://src/Shaders/Effects/Rotation/SmearRotxel.gdshader")
var nn_shader := preload("res://src/Shaders/Effects/Rotation/NearestNeighbour.gdshader")
var isometric_tile_cache := {}


## Blends canvas layers into passed image starting from the origin position
func blend_layers(
	image: Image,
	frame: Frame,
	origin := Vector2i.ZERO,
	project := Global.current_project,
	only_selected_cels := false,
	only_selected_layers := false,
) -> void:
	var frame_index := project.frames.find(frame)
	var previous_ordered_layers: Array[int] = project.ordered_layers
	project.order_layers(frame_index)
	var textures: Array[Image] = []
	# Nx4 texture, where N is the number of layers and the first row are the blend modes,
	# the second are the opacities, the third are the origins and the fourth are the
	# clipping mask booleans.
	var metadata_image := Image.create(project.layers.size(), 4, false, Image.FORMAT_R8)
	for i in project.layers.size():
		var ordered_index := project.ordered_layers[i]
		var layer := project.layers[ordered_index]
		var include := true if layer.is_visible_in_hierarchy() else false
		if only_selected_cels and include:
			var test_array := [frame_index, i]
			if not test_array in project.selected_cels:
				include = false
		if only_selected_layers and include:
			var layer_is_selected := false
			for selected_cel in project.selected_cels:
				if i == selected_cel[1]:
					layer_is_selected = true
					break
			if not layer_is_selected:
				include = false
		var cel := frame.cels[ordered_index]
		if DisplayServer.get_name() == "headless":
			blend_layers_headless(image, project, layer, cel, origin)
		else:
			if layer.is_blender():
				var cel_image := (layer as GroupLayer).blend_children(frame)
				textures.append(cel_image)
			else:
				var cel_image := layer.display_effects(cel)
				textures.append(cel_image)
			if (
				layer.is_blended_by_ancestor()
				and not only_selected_cels
				and not only_selected_layers
			):
				include = false
			set_layer_metadata_image(layer, cel, metadata_image, ordered_index, include)
	if DisplayServer.get_name() != "headless":
		var texture_array := Texture2DArray.new()
		texture_array.create_from_images(textures)
		var params := {
			"layers": texture_array,
			"metadata": ImageTexture.create_from_image(metadata_image),
		}
		var blended := Image.create(project.size.x, project.size.y, false, image.get_format())
		var gen := ShaderImageEffect.new()
		gen.generate_image(blended, blend_layers_shader, params, project.size)
		image.blend_rect(blended, Rect2i(Vector2i.ZERO, project.size), origin)
	# Re-order the layers again to ensure correct canvas drawing
	project.ordered_layers = previous_ordered_layers


func set_layer_metadata_image(
	layer: BaseLayer, cel: BaseCel, image: Image, index: int, include := true
) -> void:
	# Store the blend mode
	image.set_pixel(index, 0, Color(layer.blend_mode / 255.0, 0.0, 0.0, 0.0))
	# Store the opacity
	if layer.is_visible_in_hierarchy() and include:
		var opacity := cel.get_final_opacity(layer)
		image.set_pixel(index, 1, Color(opacity, 0.0, 0.0, 0.0))
	else:
		image.set_pixel(index, 1, Color())
	# Store the clipping mask boolean
	if layer.clipping_mask:
		image.set_pixel(index, 3, Color.RED)
	else:
		image.set_pixel(index, 3, Color.BLACK)
	if not include:
		# Store a small red value as a way to indicate that this layer should be skipped
		# Used for layers such as child layers of a group, so that the group layer itself can
		# successfully be used as a clipping mask with the layer below it.
		image.set_pixel(index, 3, Color(0.2, 0.0, 0.0, 0.0))


func blend_layers_headless(
	image: Image, project: Project, layer: BaseLayer, cel: BaseCel, origin: Vector2i
) -> void:
	var opacity := cel.get_final_opacity(layer)
	var cel_image := Image.new()
	cel_image.copy_from(cel.get_image())
	if opacity < 1.0:  # If we have cel or layer transparency
		for xx in cel_image.get_size().x:
			for yy in cel_image.get_size().y:
				var pixel_color := cel_image.get_pixel(xx, yy)
				pixel_color.a *= opacity
				cel_image.set_pixel(xx, yy, pixel_color)
	image.blend_rect(cel_image, Rect2i(Vector2i.ZERO, project.size), origin)


## Algorithm based on http://members.chello.at/easyfilter/bresenham.html
func get_ellipse_points(pos: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var array: Array[Vector2i] = []
	var x0 := pos.x
	var x1 := pos.x + (size.x - 1)
	var y0 := pos.y
	var y1 := pos.y + (size.y - 1)
	var a := absi(x1 - x0)
	var b := absi(y1 - y0)
	var b1 := b & 1
	var dx := 4 * (1 - a) * b * b
	var dy := 4 * (b1 + 1) * a * a
	var err := dx + dy + b1 * a * a
	var e2 := 0

	if x0 > x1:
		x0 = x1
		x1 += a

	if y0 > y1:
		y0 = y1

	y0 += (b + 1) / 2
	y1 = y0 - b1
	a *= 8 * a
	b1 = 8 * b * b

	while x0 <= x1:
		var v1 := Vector2i(x1, y0)
		var v2 := Vector2i(x0, y0)
		var v3 := Vector2i(x0, y1)
		var v4 := Vector2i(x1, y1)
		array.append(v1)
		array.append(v2)
		array.append(v3)
		array.append(v4)

		e2 = 2 * err
		if e2 <= dy:
			y0 += 1
			y1 -= 1
			dy += a
			err += dy

		if e2 >= dx || 2 * err > dy:
			x0 += 1
			x1 -= 1
			dx += b1
			err += dx

	while y0 - y1 < b:
		var v1 := Vector2i(x0 - 1, y0)
		var v2 := Vector2i(x1 + 1, y0)
		var v3 := Vector2i(x0 - 1, y1)
		var v4 := Vector2i(x1 + 1, y1)
		array.append(v1)
		array.append(v2)
		array.append(v3)
		array.append(v4)
		y0 += 1
		y1 -= 1

	return array


func get_ellipse_points_filled(pos: Vector2i, size: Vector2i, thickness := 1) -> Array[Vector2i]:
	var offsetted_size := size + Vector2i.ONE * (thickness - 1)
	var border := get_ellipse_points(pos, offsetted_size)
	var filling: Array[Vector2i] = []

	for x in range(1, ceili(offsetted_size.x / 2.0)):
		var fill := false
		var prev_is_true := false
		for y in range(0, ceili(offsetted_size.y / 2.0)):
			var top_l_p := Vector2i(x, y)
			var bit := border.has(pos + top_l_p)

			if bit and not fill:
				prev_is_true = true
				continue

			if not bit and (fill or prev_is_true):
				filling.append(pos + top_l_p)
				filling.append(pos + Vector2i(x, offsetted_size.y - y - 1))
				filling.append(pos + Vector2i(offsetted_size.x - x - 1, y))
				filling.append(pos + Vector2i(offsetted_size.x - x - 1, offsetted_size.y - y - 1))

				if prev_is_true:
					fill = true
					prev_is_true = false
			elif bit and fill:
				break

	return border + filling


func scale_3x(sprite: Image, tol := 0.196078) -> Image:
	var scaled := Image.create(
		sprite.get_width() * 3, sprite.get_height() * 3, sprite.has_mipmaps(), sprite.get_format()
	)
	var width_minus_one := sprite.get_width() - 1
	var height_minus_one := sprite.get_height() - 1
	for x in range(0, sprite.get_width()):
		for y in range(0, sprite.get_height()):
			var xs := 3 * x
			var ys := 3 * y

			var a := sprite.get_pixel(maxi(x - 1, 0), maxi(y - 1, 0))
			var b := sprite.get_pixel(mini(x, width_minus_one), maxi(y - 1, 0))
			var c := sprite.get_pixel(mini(x + 1, width_minus_one), maxi(y - 1, 0))
			var d := sprite.get_pixel(maxi(x - 1, 0), mini(y, height_minus_one))
			var e := sprite.get_pixel(mini(x, width_minus_one), mini(y, height_minus_one))
			var f := sprite.get_pixel(mini(x + 1, width_minus_one), mini(y, height_minus_one))
			var g := sprite.get_pixel(maxi(x - 1, 0), mini(y + 1, height_minus_one))
			var h := sprite.get_pixel(mini(x, width_minus_one), mini(y + 1, height_minus_one))
			var i := sprite.get_pixel(mini(x + 1, width_minus_one), mini(y + 1, height_minus_one))

			var db: bool = similar_colors(d, b, tol)
			var dh: bool = similar_colors(d, h, tol)
			var bf: bool = similar_colors(f, b, tol)
			var ec: bool = similar_colors(e, c, tol)
			var ea: bool = similar_colors(e, a, tol)
			var fh: bool = similar_colors(f, h, tol)
			var eg: bool = similar_colors(e, g, tol)
			var ei: bool = similar_colors(e, i, tol)

			scaled.set_pixel(maxi(xs - 1, 0), maxi(ys - 1, 0), d if (db and !dh and !bf) else e)
			scaled.set_pixel(
				xs,
				maxi(ys - 1, 0),
				b if (db and !dh and !bf and !ec) or (bf and !db and !fh and !ea) else e
			)
			scaled.set_pixel(xs + 1, maxi(ys - 1, 0), f if (bf and !db and !fh) else e)
			scaled.set_pixel(
				maxi(xs - 1, 0),
				ys,
				d if (dh and !fh and !db and !ea) or (db and !dh and !bf and !eg) else e
			)
			scaled.set_pixel(xs, ys, e)
			scaled.set_pixel(
				xs + 1, ys, f if (bf and !db and !fh and !ei) or (fh and !bf and !dh and !ec) else e
			)
			scaled.set_pixel(maxi(xs - 1, 0), ys + 1, d if (dh and !fh and !db) else e)
			scaled.set_pixel(
				xs, ys + 1, h if (fh and !bf and !dh and !eg) or (dh and !fh and !db and !ei) else e
			)
			scaled.set_pixel(xs + 1, ys + 1, f if (fh and !bf and !dh) else e)

	return scaled


func transform_image_with_algorithm(
	image: Image, params: Dictionary, algorithm: RotationAlgorithm, used_rect := Rect2i()
) -> void:
	var transformation_matrix: Transform2D = params.get("transformation_matrix", Transform2D())
	var new_image_size := used_rect.size
	if new_image_size == Vector2i.ZERO:
		new_image_size = image.get_size()
	var pivot: Vector2 = params.get("pivot", image.get_size() / 2)
	if type_is_shader(algorithm):
		transformation_matrix = transform_remove_scale(transformation_matrix)
		params["transformation_matrix"] = transformation_matrix
		params["pivot"] = pivot / Vector2(image.get_size())
		var shader := rotxel_shader
		match algorithm:
			RotationAlgorithm.CLEANEDGE:
				shader = clean_edge_shader
			RotationAlgorithm.OMNISCALE:
				shader = omniscale_shader
			RotationAlgorithm.NNS:
				shader = nn_shader
		var gen := ShaderImageEffect.new()
		gen.generate_image(image, shader, params, new_image_size)
	else:
		var angle := transformation_matrix.get_rotation()
		match algorithm:
			RotationAlgorithm.ROTXEL:
				rotxel(image, angle, pivot)
			RotationAlgorithm.NN:
				nn_rotate(image, angle, pivot)
			RotationAlgorithm.URD:
				fake_rotsprite(image, angle, pivot)
	if image is ImageExtended:
		image.convert_rgb_to_indexed()


func transform_image_with_viewport(
	original_image: Image,
	transform_matrix: Transform2D,
	pivot: Vector2,
	algorithm: RotationAlgorithm,
	used_rect := Rect2i()
) -> void:
	# Compute the transformation with pivot support
	# translate pivot to origin
	var move_to_origin := Transform2D(Vector2(1, 0), Vector2(0, 1), -pivot)
	var move_back := Transform2D(Vector2(1, 0), Vector2(0, 1), pivot)  # move pivot back
	var full_transform := move_back * transform_matrix * move_to_origin

	# Estimate new bounding box
	var bounds := get_transformed_bounds(original_image.get_size(), full_transform)
	if bounds.size.x == 0 or bounds.size.y == 0:
		return
	var viewport_size := bounds.size.ceil() as Vector2i
	if viewport_size.x == 1:
		viewport_size.x = 2
	if viewport_size.y == 1:
		viewport_size.y = 2

	# Create viewport and canvas
	var vp := RenderingServer.viewport_create()
	var canvas := RenderingServer.canvas_create()
	RenderingServer.viewport_attach_canvas(vp, canvas)
	RenderingServer.viewport_set_size(vp, viewport_size.x, viewport_size.y)
	RenderingServer.viewport_set_disable_3d(vp, true)
	RenderingServer.viewport_set_active(vp, true)
	RenderingServer.viewport_set_transparent_background(vp, true)
	RenderingServer.viewport_set_default_canvas_item_texture_filter(
		vp, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	)

	# Apply transform offset to align within new bounding box
	var ci_rid := RenderingServer.canvas_item_create()
	var offset_transform := full_transform.translated(-bounds.position)
	RenderingServer.viewport_set_canvas_transform(vp, canvas, offset_transform)
	RenderingServer.canvas_item_set_parent(ci_rid, canvas)

	# Draw the texture
	var texture := RenderingServer.texture_2d_create(original_image)
	RenderingServer.canvas_item_add_texture_rect(
		ci_rid, Rect2(Vector2.ZERO, original_image.get_size()), texture
	)
	var mat_rid := RenderingServer.material_create()
	var shader: Shader = null
	match algorithm:
		RotationAlgorithm.CLEANEDGE:
			shader = clean_edge_shader_premul_alpha
		RotationAlgorithm.OMNISCALE:
			shader = omniscale_shader_premul_alpha
		RotationAlgorithm.NNS:
			shader = nn_shader
		_:
			shader = DUMMY_PRE_MUL_ALPHA_SHADER
	if is_instance_valid(shader):
		RenderingServer.material_set_shader(mat_rid, shader.get_rid())
	RenderingServer.canvas_item_set_material(ci_rid, mat_rid)

	# Render once
	RenderingServer.viewport_set_update_mode(vp, RenderingServer.VIEWPORT_UPDATE_ONCE)
	RenderingServer.force_draw(false)
	var viewport_texture := RenderingServer.texture_2d_get(RenderingServer.viewport_get_texture(vp))

	# Clean up
	RenderingServer.free_rid(vp)
	RenderingServer.free_rid(canvas)
	RenderingServer.free_rid(ci_rid)
	RenderingServer.free_rid(mat_rid)
	RenderingServer.free_rid(texture)

	# Copy result
	if not is_instance_valid(viewport_texture):
		return
	viewport_texture.convert(original_image.get_format())
	var region := viewport_texture.get_used_rect() if used_rect == Rect2i() else used_rect
	original_image.copy_from(viewport_texture.get_region(region))

	if original_image is ImageExtended:
		original_image.convert_rgb_to_indexed()


func type_is_shader(algorithm: RotationAlgorithm) -> bool:
	return algorithm <= RotationAlgorithm.NNS


func get_transformed_bounds(image_size: Vector2i, transform: Transform2D) -> Rect2:
	var corners: Array[Vector2] = [
		transform * (Vector2(0, 0)),
		transform * (Vector2(image_size.x, 0)),
		transform * (Vector2(0, image_size.y)),
		transform * (Vector2(image_size.x, image_size.y))
	]
	var min_corner := corners[0]
	var max_corner := corners[0]
	for corner in corners:
		min_corner = min_corner.min(corner)
		max_corner = max_corner.max(corner)
	return Rect2(min_corner, max_corner - min_corner)


func transform_remove_scale(t: Transform2D) -> Transform2D:
	var x := t.x.normalized()
	var y := t.y.normalized()
	return Transform2D(x, y, Vector2.ZERO)


func rotxel(sprite: Image, angle: float, pivot: Vector2) -> void:
	if is_zero_approx(angle) or is_equal_approx(angle, TAU):
		return
	if is_equal_approx(angle, PI / 2.0) or is_equal_approx(angle, 3.0 * PI / 2.0):
		nn_rotate(sprite, angle, pivot)
		return
	if is_equal_approx(angle, PI):
		sprite.rotate_180()
		return

	var aux := Image.new()
	aux.copy_from(sprite)
	var ox: int
	var oy: int
	for x in sprite.get_size().x:
		for y in sprite.get_size().y:
			var dx := 3 * (x - pivot.x)
			var dy := 3 * (y - pivot.y)
			var found_pixel := false
			for k in range(9):
				var modk := -1 + k % 3
				var divk := -1 + int(k / 3)
				var dir := atan2(dy + divk, dx + modk)
				var mag := sqrt(pow(dx + modk, 2) + pow(dy + divk, 2))
				dir += angle
				ox = roundi(pivot.x * 3 + 1 + mag * cos(dir))
				oy = roundi(pivot.y * 3 + 1 + mag * sin(dir))

				if sprite.get_width() % 2 != 0:
					ox += 1
					oy += 1

				if (
					ox >= 0
					&& ox < sprite.get_width() * 3
					&& oy >= 0
					&& oy < sprite.get_height() * 3
				):
					found_pixel = true
					break

			if !found_pixel:
				sprite.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var fil: int = oy % 3
			var col: int = ox % 3
			var index: int = col + 3 * fil

			ox = roundi((ox - 1) / 3.0)
			oy = roundi((oy - 1) / 3.0)
			var p: Color
			if ox == 0 || ox == sprite.get_width() - 1 || oy == 0 || oy == sprite.get_height() - 1:
				p = aux.get_pixel(ox, oy)
			else:
				var a := aux.get_pixel(ox - 1, oy - 1)
				var b := aux.get_pixel(ox, oy - 1)
				var c := aux.get_pixel(ox + 1, oy - 1)
				var d := aux.get_pixel(ox - 1, oy)
				var e := aux.get_pixel(ox, oy)
				var f := aux.get_pixel(ox + 1, oy)
				var g := aux.get_pixel(ox - 1, oy + 1)
				var h := aux.get_pixel(ox, oy + 1)
				var i := aux.get_pixel(ox + 1, oy + 1)

				match index:
					0:
						p = (
							d
							if (
								similar_colors(d, b)
								&& !similar_colors(d, h)
								&& !similar_colors(b, f)
							)
							else e
						)
					1:
						p = (
							b
							if (
								(
									similar_colors(d, b)
									&& !similar_colors(d, h)
									&& !similar_colors(b, f)
									&& !similar_colors(e, c)
								)
								|| (
									similar_colors(b, f)
									&& !similar_colors(d, b)
									&& !similar_colors(f, h)
									&& !similar_colors(e, a)
								)
							)
							else e
						)
					2:
						p = (
							f
							if (
								similar_colors(b, f)
								&& !similar_colors(d, b)
								&& !similar_colors(f, h)
							)
							else e
						)
					3:
						p = (
							d
							if (
								(
									similar_colors(d, h)
									&& !similar_colors(f, h)
									&& !similar_colors(d, b)
									&& !similar_colors(e, a)
								)
								|| (
									similar_colors(d, b)
									&& !similar_colors(d, h)
									&& !similar_colors(b, f)
									&& !similar_colors(e, g)
								)
							)
							else e
						)
					4:
						p = e
					5:
						p = (
							f
							if (
								(
									similar_colors(b, f)
									&& !similar_colors(d, b)
									&& !similar_colors(f, h)
									&& !similar_colors(e, i)
								)
								|| (
									similar_colors(f, h)
									&& !similar_colors(b, f)
									&& !similar_colors(d, h)
									&& !similar_colors(e, c)
								)
							)
							else e
						)
					6:
						p = (
							d
							if (
								similar_colors(d, h)
								&& !similar_colors(f, h)
								&& !similar_colors(d, b)
							)
							else e
						)
					7:
						p = (
							h
							if (
								(
									similar_colors(f, h)
									&& !similar_colors(f, b)
									&& !similar_colors(d, h)
									&& !similar_colors(e, g)
								)
								|| (
									similar_colors(d, h)
									&& !similar_colors(f, h)
									&& !similar_colors(d, b)
									&& !similar_colors(e, i)
								)
							)
							else e
						)
					8:
						p = (
							f
							if (
								similar_colors(f, h)
								&& !similar_colors(f, b)
								&& !similar_colors(d, h)
							)
							else e
						)
			sprite.set_pixel(x, y, p)


func fake_rotsprite(sprite: Image, angle: float, pivot: Vector2) -> void:
	if is_zero_approx(angle) or is_equal_approx(angle, TAU):
		return
	if is_equal_approx(angle, PI / 2.0) or is_equal_approx(angle, 3.0 * PI / 2.0):
		nn_rotate(sprite, angle, pivot)
		return
	if is_equal_approx(angle, PI):
		sprite.rotate_180()
		return
	var selected_sprite := scale_3x(sprite)
	nn_rotate(selected_sprite, angle, pivot * 3)
	selected_sprite.resize(
		selected_sprite.get_width() / 3, selected_sprite.get_height() / 3, Image.INTERPOLATE_NEAREST
	)
	sprite.blit_rect(selected_sprite, Rect2(Vector2.ZERO, selected_sprite.get_size()), Vector2.ZERO)


func nn_rotate(sprite: Image, angle: float, pivot: Vector2) -> void:
	if is_zero_approx(angle) or is_equal_approx(angle, TAU):
		return
	if is_equal_approx(angle, PI):
		sprite.rotate_180()
		return
	var aux := Image.new()
	aux.copy_from(sprite)
	var angle_sin := sin(angle)
	var angle_cos := cos(angle)
	for x in range(sprite.get_width()):
		for y in range(sprite.get_height()):
			var ox := (x - pivot.x) * angle_cos - (y - pivot.y) * angle_sin + pivot.x
			var oy := (x - pivot.x) * angle_sin + (y - pivot.y) * angle_cos + pivot.y
			if ox >= 0 && ox < sprite.get_width() && oy >= 0 && oy < sprite.get_height():
				sprite.set_pixel(x, y, aux.get_pixel(ox, oy))
			else:
				sprite.set_pixel(x, y, Color(0, 0, 0, 0))


## Compares two colors, and returns [code]true[/code] if the difference of these colors is
## less or equal to the tolerance [param tol]. [param tol] is in the range of 0-1.
func similar_colors(c1: Color, c2: Color, tol := 0.392157) -> bool:
	return (
		absf(c1.r - c2.r) <= tol
		&& absf(c1.g - c2.g) <= tol
		&& absf(c1.b - c2.b) <= tol
		&& absf(c1.a - c2.a) <= tol
	)


func generate_isometric_rectangle(image: Image, is_gap_tile: bool) -> void:
	if isometric_tile_cache.has(image.get_size()):
		if isometric_tile_cache[image.get_size()].has(is_gap_tile):
			var cache_img: Image = isometric_tile_cache[image.get_size()][is_gap_tile]
			image.blit_rect(cache_img, Rect2i(Vector2i.ZERO, cache_img.get_size()), Vector2i.ZERO)
			return
		isometric_tile_cache.clear()
	var half_size := ((Vector2(image.get_size()) - Vector2.ONE) / 2).floor()
	var even_check = image.get_size() % 2
	var even_offset = Vector2i(even_check.x == 0, even_check.y == 0)
	var up := Vector2i(half_size.x + even_offset.x, 0)
	var right := Vector2i(image.get_size().x - 1, half_size.y)
	if is_gap_tile:
		var test = Geometry2D.bresenham_line(up, right)
		var a: Vector2i
		var b = test[-1] + Vector2i.UP
		var line_r = []
		var sub_position_x := []
		var sub_position_y := []
		var scan_dir = [Vector2i.RIGHT]
		for i in test.size():
			if up.y == test[i].y:
				a = test[i] + Vector2i.RIGHT
			var pt: Vector2i = test[i]
			if i == test.size() - 1:
				scan_dir.erase(Vector2i.RIGHT)
			for dir in scan_dir:
				if (
					Rect2i(Vector2i.ZERO, image.get_size()).has_point(test[i] + dir)
					and !line_r.has(
						Vector2i((test[i] + dir).x, image.get_size().y - 1 - (test[i] + dir).y)
					)
					and !test.has(test[i] + dir)
				):
					var small_point = test[i] + dir
					line_r.push_front(
						Vector2i(small_point.x, image.get_size().y - 1 - small_point.y)
					)
					sub_position_x.append(small_point.x)
					sub_position_y.append(image.get_size().y - 1 - small_point.y)
			if not pt + Vector2i.RIGHT in test and not scan_dir.has(Vector2i.UP):
				scan_dir.push_front(Vector2i.UP)
		var pos = Vector2i(sub_position_x.min(), sub_position_y.min())
		var sub_size_x = (b.x - a.x + 1) * 2
		var sub_size_y = (b.y - a.y + 1) * 2
		var offset_x: int = floori((sub_size_x - image.get_size().x) / 2.0)
		var offset_y: int = floori((sub_size_y - image.get_size().y) / 2.0)
		var offset := Vector2i(-offset_x, -offset_y)
		for i in line_r.size():
			var val_local = line_r[i] - pos
			line_r[i] = Vector2i(sub_size_x - 1 - val_local.x, val_local.y)
		for pixel in line_r:
			image.set_pixelv(pixel + offset, Color.WHITE)
			var left := Vector2i(sub_size_x - 1 - pixel.x, pixel.y)
			for j in range(pixel.x, left.x - 1, -1):
				image.set_pixel(j + offset.x, pixel.y + offset.y, Color.WHITE)
				var mirror_y := Vector2i(j, sub_size_y - 1 - pixel.y)
				for k in range(pixel.y, mirror_y.y + 1):
					image.set_pixel(j + offset.x, k + offset.y, Color.WHITE)
			var mirror_right := Vector2i(pixel.x, sub_size_y - 1 - pixel.y)
			image.set_pixelv(mirror_right + offset, Color.WHITE)
			isometric_tile_cache.get_or_add(image.get_size(), {})[is_gap_tile] = image.duplicate()
		return

	var up_right := Geometry2D.bresenham_line(up, right)
	for pixel in up_right:
		image.set_pixelv(pixel, Color.WHITE)
		var left := Vector2i(image.get_size().x - 1 - pixel.x, pixel.y)
		for j in range(pixel.x, left.x - 1, -1):
			image.set_pixel(j, pixel.y, Color.WHITE)
			var mirror_y := Vector2i(j, image.get_size().y - 1 - pixel.y)
			for k in range(pixel.y, mirror_y.y + 1):
				image.set_pixel(j, k, Color.WHITE)
		var mirror_right := Vector2i(pixel.x, image.get_size().y - 1 - pixel.y)
		image.set_pixelv(mirror_right, Color.WHITE)
		isometric_tile_cache.get_or_add(image.get_size(), {})[is_gap_tile] = image.duplicate()


func generate_hexagonal_pointy_top(image: Image) -> void:
	var half_size := image.get_size() / 2
	var quarter_size := image.get_size() / 4
	var three_quarters_size := (image.get_size() * 3) / 4
	var up := Vector2i(half_size.x, 0)
	var quarter := Vector2i(image.get_size().x - 1, quarter_size.y)
	var line := Geometry2D.bresenham_line(up, quarter)
	for pixel in line:
		image.set_pixelv(pixel, Color.WHITE)
		var mirror := Vector2i(image.get_size().x - 1 - pixel.x, pixel.y)
		for j in range(pixel.x, mirror.x - 1, -1):
			image.set_pixel(j, pixel.y, Color.WHITE)
	var three_quarters := Vector2i(image.get_size().x - 1, three_quarters_size.y - 1)
	line = Geometry2D.bresenham_line(quarter, three_quarters)
	for pixel in line:
		image.set_pixelv(pixel, Color.WHITE)
		var mirror := Vector2i(image.get_size().x - 1 - pixel.x, pixel.y)
		for j in range(pixel.x, mirror.x - 1, -1):
			image.set_pixel(j, pixel.y, Color.WHITE)
	var down := Vector2i(half_size.x, image.get_size().y - 1)
	line = Geometry2D.bresenham_line(three_quarters, down)
	for pixel in line:
		image.set_pixelv(pixel, Color.WHITE)
		var mirror := Vector2i(image.get_size().x - 1 - pixel.x, pixel.y)
		for j in range(pixel.x, mirror.x - 1, -1):
			image.set_pixel(j, pixel.y, Color.WHITE)


func generate_hexagonal_flat_top(image: Image) -> void:
	var half_size := image.get_size() / 2
	var quarter_size := image.get_size() / 4
	var three_quarters_size := (image.get_size() * 3) / 4
	var left := Vector2i(0, half_size.y)
	var quarter := Vector2i(quarter_size.x, image.get_size().y - 1)
	var line := Geometry2D.bresenham_line(left, quarter)
	for pixel in line:
		image.set_pixelv(pixel, Color.WHITE)
		var mirror := Vector2i(pixel.x, image.get_size().y - 1 - pixel.y)
		for j in range(pixel.y, mirror.y - 1, -1):
			image.set_pixel(pixel.x, j, Color.WHITE)
	var three_quarters := Vector2i(three_quarters_size.x - 1, image.get_size().y - 1)
	line = Geometry2D.bresenham_line(quarter, three_quarters)
	for pixel in line:
		image.set_pixelv(pixel, Color.WHITE)
		var mirror := Vector2i(pixel.x, image.get_size().y - 1 - pixel.y)
		for j in range(pixel.y, mirror.y - 1, -1):
			image.set_pixel(pixel.x, j, Color.WHITE)
	var down := Vector2i(image.get_size().x - 1, half_size.y)
	line = Geometry2D.bresenham_line(three_quarters, down)
	for pixel in line:
		image.set_pixelv(pixel, Color.WHITE)
		var mirror := Vector2i(pixel.x, image.get_size().y - 1 - pixel.y)
		for j in range(pixel.y, mirror.y - 1, -1):
			image.set_pixel(pixel.x, j, Color.WHITE)


# Image effects
func center(indices: Array) -> void:
	var project := Global.current_project
	Global.canvas.selection.transform_content_confirm()
	var redo_data := {}
	var undo_data := {}
	project.undo_redo.create_action("Center Frames")
	for frame in indices:
		# Find used rect of the current frame (across all of the layers)
		var used_rect := Rect2i()
		for cel in project.frames[frame].cels:
			if not cel is PixelCel:
				continue
			var cel_rect := cel.get_image().get_used_rect()
			if cel_rect.has_area():
				used_rect = used_rect.merge(cel_rect) if used_rect.has_area() else cel_rect
		if not used_rect.has_area():
			continue

		# Now apply centering
		var offset: Vector2i = (0.5 * (project.size - used_rect.size)).floor()
		for cel in project.frames[frame].cels:
			if not cel is PixelCel:
				continue
			var cel_image := (cel as PixelCel).get_image()
			var tmp_centered := project.new_empty_image()
			tmp_centered.blend_rect(cel_image, used_rect, offset)
			var centered := ImageExtended.new()
			centered.copy_from_custom(tmp_centered, cel_image.is_indexed)
			if cel is CelTileMap:
				var tilemap_cel := cel as CelTileMap
				var tilemap_offset := (offset - used_rect.position) % tilemap_cel.get_tile_size()
				tilemap_cel.serialize_undo_data_source_image(
					centered, redo_data, undo_data, tilemap_offset
				)
			centered.add_data_to_dictionary(redo_data, cel_image)
			cel_image.add_data_to_dictionary(undo_data)
	project.deserialize_cel_undo_data(redo_data, undo_data)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.commit_action()


func scale_project(width: int, height: int, interpolation: int) -> void:
	var redo_data := {}
	var undo_data := {}
	var tilesets: Array[TileSetCustom] = []
	for cel in Global.current_project.get_all_pixel_cels():
		if not cel is PixelCel:
			continue
		var cel_image := (cel as PixelCel).get_image()
		var sprite := resize_image(cel_image, width, height, interpolation) as ImageExtended
		if cel is CelTileMap:
			var tilemap_cel := cel as CelTileMap
			var skip_tileset_undo := not tilesets.has(tilemap_cel.tileset)
			tilemap_cel.serialize_undo_data_source_image(
				sprite, redo_data, undo_data, Vector2i.ZERO, skip_tileset_undo, interpolation
			)
			tilesets.append(tilemap_cel.tileset)
		sprite.add_data_to_dictionary(redo_data, cel_image)
		cel_image.add_data_to_dictionary(undo_data)

	general_do_and_undo_scale(width, height, redo_data, undo_data)


func resize_image(
	image: Image, width: int, height: int, interpolation: Image.Interpolation
) -> Image:
	var new_image: Image
	if image is ImageExtended:
		new_image = ImageExtended.new()
		new_image.is_indexed = image.is_indexed
		new_image.copy_from(image)
		new_image.select_palette("", false)
	else:
		new_image = Image.new()
		new_image.copy_from(image)
	if interpolation == Interpolation.SCALE3X:
		var times := Vector2i(
			ceili(width / (3.0 * new_image.get_width())),
			ceili(height / (3.0 * new_image.get_height()))
		)
		for _j in range(maxi(times.x, times.y)):
			new_image.copy_from(scale_3x(new_image))
		new_image.resize(width, height, Image.INTERPOLATE_NEAREST)
	elif interpolation == Interpolation.CLEANEDGE:
		var gen := ShaderImageEffect.new()
		gen.generate_image(new_image, clean_edge_shader, {}, Vector2i(width, height), false)
	elif interpolation == Interpolation.OMNISCALE and omniscale_shader:
		var gen := ShaderImageEffect.new()
		gen.generate_image(new_image, omniscale_shader, {}, Vector2i(width, height), false)
	else:
		new_image.resize(width, height, interpolation)
	if new_image is ImageExtended:
		new_image.on_size_changed()
	return new_image


## Sets the size of the project to be the same as the size of the active selection.
func crop_to_selection() -> void:
	if not Global.current_project.has_selection:
		return
	Global.canvas.selection.transform_content_confirm()
	var redo_data := {}
	var undo_data := {}
	var rect := Global.current_project.selection_map.get_selection_rect(Global.current_project)
	# Loop through all the cels to crop them
	for cel in Global.current_project.get_all_pixel_cels():
		var cel_image := cel.get_image()
		var tmp_cropped := cel_image.get_region(rect)
		var cropped := ImageExtended.new()
		cropped.copy_from_custom(tmp_cropped, cel_image.is_indexed)
		if cel is CelTileMap:
			var tilemap_cel := cel as CelTileMap
			var offset := rect.position
			tilemap_cel.serialize_undo_data_source_image(cropped, redo_data, undo_data, -offset)
		cropped.add_data_to_dictionary(redo_data, cel_image)
		cel_image.add_data_to_dictionary(undo_data)

	general_do_and_undo_scale(rect.size.x, rect.size.y, redo_data, undo_data)


## Automatically makes the project smaller by looping through all of the cels and
## trimming out the pixels that are transparent in all cels.
func crop_to_content() -> void:
	Global.canvas.selection.transform_content_confirm()
	var used_rect := Rect2i()
	for cel in Global.current_project.get_all_pixel_cels():
		if not cel is PixelCel:
			continue
		var cel_used_rect := cel.get_image().get_used_rect()
		if cel_used_rect == Rect2i(0, 0, 0, 0):  # If the cel has no content
			continue

		if used_rect == Rect2i(0, 0, 0, 0):  # If we still haven't found the first cel with content
			used_rect = cel_used_rect
		else:
			used_rect = used_rect.merge(cel_used_rect)

	# If no layer has any content, just return
	if used_rect == Rect2i(0, 0, 0, 0):
		return

	var width := used_rect.size.x
	var height := used_rect.size.y
	var redo_data := {}
	var undo_data := {}
	# Loop through all the cels to trim them
	for cel in Global.current_project.get_all_pixel_cels():
		var cel_image := cel.get_image()
		var tmp_cropped := cel_image.get_region(used_rect)
		var cropped := ImageExtended.new()
		cropped.copy_from_custom(tmp_cropped, cel_image.is_indexed)
		if cel is CelTileMap:
			var tilemap_cel := cel as CelTileMap
			var offset := used_rect.position
			tilemap_cel.serialize_undo_data_source_image(cropped, redo_data, undo_data, -offset)
		cropped.add_data_to_dictionary(redo_data, cel_image)
		cel_image.add_data_to_dictionary(undo_data)

	general_do_and_undo_scale(width, height, redo_data, undo_data)


func resize_canvas(width: int, height: int, offset_x: int, offset_y: int) -> void:
	var redo_data := {}
	var undo_data := {}
	for cel in Global.current_project.get_all_pixel_cels():
		var cel_image := cel.get_image()
		var resized := ImageExtended.create_custom(
			width, height, cel_image.has_mipmaps(), cel_image.get_format(), cel_image.is_indexed
		)
		resized.blend_rect(
			cel_image, Rect2i(Vector2i.ZERO, cel_image.get_size()), Vector2i(offset_x, offset_y)
		)
		resized.convert_rgb_to_indexed()
		if cel is CelTileMap:
			var tilemap_cel := cel as CelTileMap
			var offset := Vector2i(offset_x, offset_y)
			tilemap_cel.serialize_undo_data_source_image(resized, redo_data, undo_data, offset)
		resized.add_data_to_dictionary(redo_data, cel_image)
		cel_image.add_data_to_dictionary(undo_data)

	general_do_and_undo_scale(width, height, redo_data, undo_data)


func general_do_and_undo_scale(
	width: int, height: int, redo_data: Dictionary, undo_data: Dictionary
) -> void:
	var project := Global.current_project
	var size := Vector2i(width, height)
	var x_ratio := float(project.size.x) / width
	var y_ratio := float(project.size.y) / height

	var selection_map_copy := SelectionMap.new()
	selection_map_copy.copy_from(project.selection_map)
	selection_map_copy.crop(size.x, size.y)
	redo_data[project.selection_map] = selection_map_copy.data
	undo_data[project.selection_map] = project.selection_map.data

	var new_x_symmetry_point := project.x_symmetry_point / x_ratio
	var new_y_symmetry_point := project.y_symmetry_point / y_ratio
	var new_x_symmetry_axis_points := project.x_symmetry_axis.points
	var new_y_symmetry_axis_points := project.y_symmetry_axis.points
	new_x_symmetry_axis_points[0].y /= y_ratio
	new_x_symmetry_axis_points[1].y /= y_ratio
	new_y_symmetry_axis_points[0].x /= x_ratio
	new_y_symmetry_axis_points[1].x /= x_ratio

	project.undo_redo.create_action("Scale")
	project.undo_redo.add_do_property(project, "size", size)
	project.undo_redo.add_do_property(project, "x_symmetry_point", new_x_symmetry_point)
	project.undo_redo.add_do_property(project, "y_symmetry_point", new_y_symmetry_point)
	project.undo_redo.add_do_property(project.x_symmetry_axis, "points", new_x_symmetry_axis_points)
	project.undo_redo.add_do_property(project.y_symmetry_axis, "points", new_y_symmetry_axis_points)
	project.deserialize_cel_undo_data(redo_data, undo_data)
	project.undo_redo.add_undo_property(project, "size", project.size)
	project.undo_redo.add_undo_property(project, "x_symmetry_point", project.x_symmetry_point)
	project.undo_redo.add_undo_property(project, "y_symmetry_point", project.y_symmetry_point)
	project.undo_redo.add_undo_property(
		project.x_symmetry_axis, "points", project.x_symmetry_axis.points
	)
	project.undo_redo.add_undo_property(
		project.y_symmetry_axis, "points", project.y_symmetry_axis.points
	)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.commit_action()
