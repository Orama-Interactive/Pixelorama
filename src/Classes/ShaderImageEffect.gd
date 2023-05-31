class_name ShaderImageEffect
extends RefCounted
# Helper class to generate image effects using shaders
signal done


func generate_image(img: Image, shader: Shader, params: Dictionary, size: Vector2) -> void:
	false # img.unlock() # TODOConverter40, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
	# duplicate shader before modifying code to avoid affecting original resource
	shader = shader.duplicate()
	shader.code = shader.code.replace("unshaded", "unshaded, blend_premul_alpha")
	var vp := RenderingServer.viewport_create()
	var canvas := RenderingServer.canvas_create()
	RenderingServer.viewport_attach_canvas(vp, canvas)
	RenderingServer.viewport_set_size(vp, size.x, size.y)
	RenderingServer.viewport_set_disable_3d(vp, true)
	RenderingServer.viewport_set_usage(vp, RenderingServer.VIEWPORT_USAGE_2D)
	RenderingServer.viewport_set_active(vp, true)
	RenderingServer.viewport_set_transparent_background(vp, true)

	var ci_rid := RenderingServer.canvas_item_create()
	RenderingServer.viewport_set_canvas_transform(vp, canvas, Transform3D())
	RenderingServer.canvas_item_set_parent(ci_rid, canvas)
	var texture := RenderingServer.texture_create_from_image(img) #,0
	RenderingServer.canvas_item_add_texture_rect(ci_rid, Rect2(Vector2.ZERO, size), texture)

	var mat_rid := RenderingServer.material_create()
	RenderingServer.material_set_shader(mat_rid, shader.get_rid())
	RenderingServer.canvas_item_set_material(ci_rid, mat_rid)
	for key in params:
		RenderingServer.material_set_param(mat_rid, key, params[key])

	RenderingServer.viewport_set_update_mode(vp, RenderingServer.VIEWPORT_UPDATE_ONCE)
	RenderingServer.viewport_set_vflip(vp, true)
	RenderingServer.force_draw(false)
	var viewport_texture := Image.new()
	viewport_texture = RenderingServer.texture_get_data(RenderingServer.viewport_get_texture(vp))
	RenderingServer.free_rid(vp)
	RenderingServer.free_rid(canvas)
	RenderingServer.free_rid(ci_rid)
	RenderingServer.free_rid(mat_rid)
	RenderingServer.free_rid(texture)
	viewport_texture.convert(Image.FORMAT_RGBA8)
	img.copy_from(viewport_texture)
	emit_signal("done")
