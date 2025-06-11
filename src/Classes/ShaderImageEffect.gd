class_name ShaderImageEffect
extends RefCounted
## Helper class to generate image effects using shaders

signal done
var cache_mat_rid: RID  # reference to the cache material
var cache_shader: Shader  # it's just used to keep track of shader when dest_mat_after_gen is false


func generate_image(
	img: Image,
	shader: Shader,
	params: Dictionary,
	size: Vector2i,
	respect_indexed := true,
	dest_mat_after_gen := true
) -> void:
	# duplicate shader before modifying code to avoid affecting original resource
	var resized_width := false
	var resized_height := false
	if size.x == 1:
		size.x = 2
		img.crop(2, img.get_height())
		resized_width = true
	if size.y == 1:
		size.y = 2
		img.crop(img.get_width(), 2)
		resized_height = true
	shader = shader.duplicate()
	shader.code = shader.code.replace("unshaded", "unshaded, blend_premul_alpha")
	var vp := RenderingServer.viewport_create()
	var canvas := RenderingServer.canvas_create()
	RenderingServer.viewport_attach_canvas(vp, canvas)
	RenderingServer.viewport_set_size(vp, size.x, size.y)
	RenderingServer.viewport_set_disable_3d(vp, true)
	RenderingServer.viewport_set_active(vp, true)
	RenderingServer.viewport_set_transparent_background(vp, true)
	RenderingServer.viewport_set_default_canvas_item_texture_filter(
		vp, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	)

	var ci_rid := RenderingServer.canvas_item_create()
	RenderingServer.viewport_set_canvas_transform(vp, canvas, Transform3D())
	RenderingServer.canvas_item_set_parent(ci_rid, canvas)
	var texture := RenderingServer.texture_2d_create(img)
	RenderingServer.canvas_item_add_texture_rect(ci_rid, Rect2(Vector2.ZERO, size), texture)

	if not cache_mat_rid.is_valid():
		cache_mat_rid = RenderingServer.material_create()
		RenderingServer.material_set_shader(cache_mat_rid, shader.get_rid())
		cache_shader = shader
	RenderingServer.canvas_item_set_material(ci_rid, cache_mat_rid)
	for key in params:
		var param = params[key]
		if param is Texture2D or param is Texture2DArray:
			RenderingServer.material_set_param(cache_mat_rid, key, [param])
		else:
			RenderingServer.material_set_param(cache_mat_rid, key, param)

	RenderingServer.viewport_set_update_mode(vp, RenderingServer.VIEWPORT_UPDATE_ONCE)
	RenderingServer.force_draw(false)
	var viewport_texture := RenderingServer.texture_2d_get(RenderingServer.viewport_get_texture(vp))
	RenderingServer.free_rid(vp)
	RenderingServer.free_rid(canvas)
	RenderingServer.free_rid(ci_rid)
	if dest_mat_after_gen:
		# NOTE: A lot of time gets wasted through material_set_shader so we should cache it if
		# shader remains the same for the next potential generation as well
		# this reduces the generation time by about 40%
		RenderingServer.free_rid(cache_mat_rid)
		cache_mat_rid = RID()
		cache_shader = null
	RenderingServer.free_rid(texture)
	if not is_instance_valid(viewport_texture):  # Very rare bug
		done.emit()
		return
	viewport_texture.convert(img.get_format())
	img.copy_from(viewport_texture)
	if resized_width:
		img.crop(img.get_width() - 1, img.get_height())
	if resized_height:
		img.crop(img.get_width(), img.get_height() - 1)
	if img is ImageExtended and respect_indexed:
		img.convert_rgb_to_indexed()
	done.emit()
