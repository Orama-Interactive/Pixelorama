class_name ShaderImageEffect
extends Reference
# Helper class to generate image effects using shaders
signal done


func generate_image(img: Image, shader: Shader, params: Dictionary, size: Vector2) -> void:
	img.unlock()
	# duplicate shader before modifying code to avoid affecting original resource
	shader = shader.duplicate()
	shader.code = shader.code.replace("unshaded", "unshaded, blend_premul_alpha")
	var vp := VisualServer.viewport_create()
	var canvas := VisualServer.canvas_create()
	VisualServer.viewport_attach_canvas(vp, canvas)
	VisualServer.viewport_set_size(vp, size.x, size.y)
	VisualServer.viewport_set_disable_3d(vp, true)
	VisualServer.viewport_set_usage(vp, VisualServer.VIEWPORT_USAGE_2D)
	VisualServer.viewport_set_active(vp, true)
	VisualServer.viewport_set_transparent_background(vp, true)

	var ci_rid := VisualServer.canvas_item_create()
	VisualServer.viewport_set_canvas_transform(vp, canvas, Transform())
	VisualServer.canvas_item_set_parent(ci_rid, canvas)
	var texture := VisualServer.texture_create_from_image(img, 0)
	VisualServer.canvas_item_add_texture_rect(ci_rid, Rect2(Vector2.ZERO, size), texture)

	var mat_rid := VisualServer.material_create()
	VisualServer.material_set_shader(mat_rid, shader.get_rid())
	VisualServer.canvas_item_set_material(ci_rid, mat_rid)
	for key in params:
		VisualServer.material_set_param(mat_rid, key, params[key])

	VisualServer.viewport_set_update_mode(vp, VisualServer.VIEWPORT_UPDATE_ONCE)
	VisualServer.viewport_set_vflip(vp, true)
	VisualServer.force_draw(false)
	var viewport_texture := Image.new()
	viewport_texture = VisualServer.texture_get_data(VisualServer.viewport_get_texture(vp))
	VisualServer.free_rid(vp)
	VisualServer.free_rid(canvas)
	VisualServer.free_rid(ci_rid)
	VisualServer.free_rid(mat_rid)
	VisualServer.free_rid(texture)
	viewport_texture.convert(Image.FORMAT_RGBA8)
	img.copy_from(viewport_texture)
	emit_signal("done")
