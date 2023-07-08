extends RefCounted

var _shader: Shader


func get_indexed_datas(image: Image, colors: Array) -> PackedByteArray:
	_shader = preload("./lookup_color.gdshader")
	return _convert(image, colors)


func get_similar_indexed_datas(image: Image, colors: Array) -> PackedByteArray:
	_shader = preload("./lookup_similar.gdshader")
	return _convert(image, colors)


func _convert(image: Image, colors: Array) -> PackedByteArray:
	var vp = RenderingServer.viewport_create()
	var canvas = RenderingServer.canvas_create()
	RenderingServer.viewport_attach_canvas(vp, canvas)
	RenderingServer.viewport_set_size(vp, image.get_width(), image.get_height())
	RenderingServer.viewport_set_disable_3d(vp, true)
	RenderingServer.viewport_set_usage(vp, RenderingServer.VIEWPORT_USAGE_2D)
	RenderingServer.viewport_set_hdr(vp, true)
	RenderingServer.viewport_set_active(vp, true)

	var ci_rid = RenderingServer.canvas_item_create()
	RenderingServer.viewport_set_canvas_transform(vp, canvas, Transform3D())
	RenderingServer.canvas_item_set_parent(ci_rid, canvas)
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	RenderingServer.canvas_item_add_texture_rect(
		ci_rid, Rect2(Vector2(0, 0), image.get_size()), texture
	)

	var mat_rid = RenderingServer.material_create()
	RenderingServer.material_set_shader(mat_rid, _shader.get_rid())
	var lut = Image.new()
	lut.create(256, 1, false, Image.FORMAT_RGB8)
	lut.fill(Color8(colors[0][0], colors[0][1], colors[0][2]))
	false # lut.lock() # TODOConverter40, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
	for i in colors.size():
		lut.set_pixel(i, 0, Color8(colors[i][0], colors[i][1], colors[i][2]))
	var lut_tex = ImageTexture.new()
	lut_tex.create_from_image(lut)
	RenderingServer.material_set_param(mat_rid, "lut", lut_tex)
	RenderingServer.canvas_item_set_material(ci_rid, mat_rid)

	RenderingServer.viewport_set_update_mode(vp, RenderingServer.VIEWPORT_UPDATE_ONCE)
	RenderingServer.viewport_set_vflip(vp, true)
	RenderingServer.force_draw(false)
	image = RenderingServer.texture_get_data(RenderingServer.viewport_get_texture(vp))

	RenderingServer.free_rid(vp)
	RenderingServer.free_rid(canvas)
	RenderingServer.free_rid(ci_rid)
	RenderingServer.free_rid(mat_rid)

	image.convert(Image.FORMAT_R8)
	return image.get_data()
