class_name VectorCel
extends BaseCel
# A class for the properties of cels in VectorLayers.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).
# The "vshapes" variable stores the cel's content, VectorShapes

var vshapes := [] # Array[BaseVectorShape]

func _init(_vshapes := [], _opacity := 1.0, _image_texture: ImageTexture = null) -> void:
	vshapes = _vshapes

	# Placeholder:
	# NOTE: Using the same font as the UI will cause an id_map error after updating the font (so its duplicated)
	var test_font =  preload("res://assets/fonts/Roboto-Regular.tres").duplicate(true)
	test_font.font_data.override_oversampling = 1

	var text_vshape := TextVectorShape.new()
	text_vshape.pos = Vector2(1, 20)
	text_vshape.text = "Hello\nworld"
	text_vshape.font = test_font
	text_vshape.font_size = 12
	text_vshape.outline_size = 1
	text_vshape.extra_spacing = Vector2(0, 0)
	text_vshape.color = Color.red
	text_vshape.outline_color = Color.white
	text_vshape.antialiased = false
	vshapes.append(text_vshape)

	test_font = test_font.duplicate(true)
	text_vshape = TextVectorShape.new()
	text_vshape.pos = Vector2(1, 60)
	text_vshape.text = "Another\nTest!"
	text_vshape.font = test_font
	text_vshape.font_size = 8
	text_vshape.outline_size = 3
	text_vshape.extra_spacing = Vector2(3, 0)
	text_vshape.color = Color.white
	text_vshape.outline_color = Color.blue
	text_vshape.antialiased = true
	vshapes.append(text_vshape)

	if _image_texture:
		image_texture = _image_texture
	else:
		# TODO: Can we prevent an extra update_texture when opening files (since it can't be deserialized until it has all cels)
		# TODO: Is it possible to use the viewport texture directly?
		image_texture = ImageTexture.new()
		update_texture()
	opacity = _opacity


func get_content():
	return vshapes


func set_content(content, texture: ImageTexture = null) -> void:
	vshapes = content
	if is_instance_valid(texture):
		image_texture = texture
		if image_texture.get_size() != Global.current_project.size:
			update_texture()
	else:
		update_texture()


func create_empty_content():
	return []


func copy_content():
	var copy_vshapes := []
	for vshape in vshapes:
		var copy = vshape.get_script().new()
		copy.deserialize(vshape.serialize())
	return copy_vshapes


func get_image() -> Image:
	return image_texture.get_data()


func update_texture() -> void:
	var start_msec := Time.get_ticks_msec()  # For benchmark

	var vp := VisualServer.viewport_create()
	var canvas := VisualServer.canvas_create()
	VisualServer.viewport_attach_canvas(vp, canvas)
	VisualServer.viewport_set_size(vp, Global.current_project.size.x, Global.current_project.size.y)
	VisualServer.viewport_set_disable_3d(vp, true)
	VisualServer.viewport_set_usage(vp, VisualServer.VIEWPORT_USAGE_2D)
	VisualServer.viewport_set_active(vp, true)
	VisualServer.viewport_set_transparent_background(vp, true)

	var ci_rid := VisualServer.canvas_item_create()
	VisualServer.viewport_set_canvas_transform(vp, canvas, Transform())
	VisualServer.canvas_item_set_parent(ci_rid, canvas)

	for vshape in vshapes:
		vshape.draw(ci_rid)

	VisualServer.viewport_set_update_mode(vp, VisualServer.VIEWPORT_UPDATE_ONCE)
	VisualServer.viewport_set_vflip(vp, true)  # TODO: May not be needed with 2 renders
	VisualServer.force_draw(false)
	var viewport_texture := VisualServer.texture_get_data(VisualServer.viewport_get_texture(vp))
	VisualServer.free_rid(vp)
	VisualServer.free_rid(canvas)
	VisualServer.free_rid(ci_rid)

	# Perhaps texture_set_proxy will allow for faster updates to image_texture?

	# TODO: This should be able to be made faster:
	var shader_effect := ShaderImageEffect.new()
	shader_effect.generate_image(viewport_texture, preload("res://src/Shaders/VectorRenderColorCorrect.gdshader"), {}, Global.current_project.size)

	viewport_texture.convert(Image.FORMAT_RGBA8)
	image_texture.create_from_image(viewport_texture, 0)
	print("VectorCel update time (msec): ", Time.get_ticks_msec() - start_msec)



func instantiate_cel_button() -> Node:
	var cel_button = Global.pixel_cel_button_node.instance()
	return cel_button
