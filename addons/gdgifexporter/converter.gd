extends Reference


var _shader: Shader


func get_indexed_datas(image: Image, colors: Array) -> PoolByteArray:
	_shader = preload("./lookup_color.shader")
	return _convert(image, colors)


func get_similar_indexed_datas(image: Image, colors: Array) -> PoolByteArray:
	_shader = preload("./lookup_similar.shader")
	return _convert(image, colors)


func _convert(image: Image, colors: Array) -> PoolByteArray:
	var vp = VisualServer.viewport_create()
	var canvas = VisualServer.canvas_create()
	VisualServer.viewport_attach_canvas(vp, canvas)
	VisualServer.viewport_set_size(vp, image.get_width(), image.get_height())
	VisualServer.viewport_set_disable_3d(vp, true)
	VisualServer.viewport_set_usage(vp, VisualServer.VIEWPORT_USAGE_2D)
	VisualServer.viewport_set_hdr(vp, true)
	VisualServer.viewport_set_active(vp, true)

	var ci_rid = VisualServer.canvas_item_create()
	VisualServer.viewport_set_canvas_transform(vp, canvas, Transform())
	VisualServer.canvas_item_set_parent(ci_rid, canvas)
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	VisualServer.canvas_item_add_texture_rect(ci_rid, Rect2(Vector2(0, 0), image.get_size()), texture)

	var mat_rid = VisualServer.material_create()
	VisualServer.material_set_shader(mat_rid, _shader.get_rid())
	var lut = Image.new()
	lut.create(256, 1, false, Image.FORMAT_RGB8)
	lut.fill(Color8(colors[0][0], colors[0][1], colors[0][2]))
	lut.lock()
	for i in colors.size():
		lut.set_pixel(i, 0, Color8(colors[i][0], colors[i][1], colors[i][2]))
	var lut_tex = ImageTexture.new()
	lut_tex.create_from_image(lut)
	VisualServer.material_set_param(mat_rid, "lut", lut_tex)
	VisualServer.canvas_item_set_material(ci_rid, mat_rid)

	VisualServer.viewport_set_update_mode(vp, VisualServer.VIEWPORT_UPDATE_ONCE)
	VisualServer.viewport_set_vflip(vp, true)
	VisualServer.force_draw(false)
	image = VisualServer.texture_get_data(VisualServer.viewport_get_texture(vp))

	VisualServer.free_rid(vp)
	VisualServer.free_rid(canvas)
	VisualServer.free_rid(ci_rid)
	VisualServer.free_rid(mat_rid)

	image.convert(Image.FORMAT_R8)
	return image.get_data()
