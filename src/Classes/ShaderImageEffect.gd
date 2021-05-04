class_name ShaderImageEffect extends Reference
# Helper class to generate image effects using shaders
signal done

func generate_image(_img : Image,_shaderpath: String, _params : Dictionary , size : Vector2 = Global.current_project.size):
	var shader = load(_shaderpath)
	_img.unlock()
	var viewport_texture := Image.new()
	var vp = VisualServer.viewport_create()
	var canvas = VisualServer.canvas_create()
	VisualServer.viewport_attach_canvas(vp, canvas)
	VisualServer.viewport_set_size(vp, size.x, size.y)
	VisualServer.viewport_set_disable_3d(vp, true)
	VisualServer.viewport_set_usage(vp, VisualServer.VIEWPORT_USAGE_2D)
	VisualServer.viewport_set_hdr(vp, true)
	VisualServer.viewport_set_active(vp, true)
	VisualServer.viewport_set_transparent_background(vp, true)

	var ci_rid = VisualServer.canvas_item_create()
	VisualServer.viewport_set_canvas_transform(vp, canvas, Transform())
	VisualServer.canvas_item_set_parent(ci_rid, canvas)
	var texture = ImageTexture.new()
	texture.create_from_image(_img)
	VisualServer.canvas_item_add_texture_rect(ci_rid, Rect2(Vector2(0, 0), size), texture)

	var mat_rid = VisualServer.material_create()
	VisualServer.material_set_shader(mat_rid, shader.get_rid())
	VisualServer.canvas_item_set_material(ci_rid, mat_rid)
	for key in _params:
		VisualServer.material_set_param(mat_rid, key, _params[key])

	VisualServer.viewport_set_update_mode(vp, VisualServer.VIEWPORT_UPDATE_ONCE)
	VisualServer.viewport_set_vflip(vp, true)
	VisualServer.force_draw(false)
	viewport_texture = VisualServer.texture_get_data(VisualServer.viewport_get_texture(vp))
	VisualServer.free_rid(vp)
	VisualServer.free_rid(canvas)
	VisualServer.free_rid(ci_rid)
	VisualServer.free_rid(mat_rid)
	viewport_texture.convert(Image.FORMAT_RGBA8)
	#Global.canvas.handle_undo("Draw")
	_img.copy_from(viewport_texture)
	#Global.canvas.handle_redo("Draw")
	_img.lock()
	emit_signal("done")
