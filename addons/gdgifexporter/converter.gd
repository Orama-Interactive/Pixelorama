extends RefCounted

var _shader: Shader


func get_indexed_datas(image: Image, colors: Array) -> PackedByteArray:
	_shader = preload("./lookup_color.gdshader")
	return _convert(image, colors)


func get_similar_indexed_datas(image: Image, colors: Array) -> PackedByteArray:
	_shader = preload("./lookup_similar.gdshader")
	return _convert(image, colors)


func _convert(image: Image, colors: Array) -> PackedByteArray:
	var vp := RenderingServer.viewport_create()
	var canvas := RenderingServer.canvas_create()
	RenderingServer.viewport_attach_canvas(vp, canvas)
	RenderingServer.viewport_set_size(vp, image.get_width(), image.get_height())
	RenderingServer.viewport_set_disable_3d(vp, true)
	RenderingServer.viewport_set_active(vp, true)

	var ci_rid := RenderingServer.canvas_item_create()
	RenderingServer.viewport_set_canvas_transform(vp, canvas, Transform3D())
	RenderingServer.canvas_item_set_parent(ci_rid, canvas)
	var texture := ImageTexture.create_from_image(image)
	RenderingServer.canvas_item_add_texture_rect(
		ci_rid, Rect2(Vector2.ZERO, image.get_size()), texture
	)

	var mat_rid := RenderingServer.material_create()
	RenderingServer.material_set_shader(mat_rid, _shader.get_rid())
	var lut := Image.create(256, 1, false, Image.FORMAT_RGB8)
	lut.fill(Color8(colors[0][0], colors[0][1], colors[0][2]))
	for i in colors.size():
		lut.set_pixel(i, 0, Color8(colors[i][0], colors[i][1], colors[i][2]))
	var lut_tex := ImageTexture.create_from_image(lut)
	# Not sure why putting lut_tex is an array is needed, but without it, it doesn't work
	RenderingServer.material_set_param(mat_rid, "lut", [lut_tex])
	RenderingServer.canvas_item_set_material(ci_rid, mat_rid)

	RenderingServer.viewport_set_update_mode(vp, RenderingServer.VIEWPORT_UPDATE_ONCE)
	RenderingServer.force_draw(false)
	image = RenderingServer.texture_2d_get(RenderingServer.viewport_get_texture(vp))

	RenderingServer.free_rid(vp)
	RenderingServer.free_rid(canvas)
	RenderingServer.free_rid(ci_rid)
	RenderingServer.free_rid(mat_rid)

	image.convert(Image.FORMAT_R8)
	return image.get_data()
