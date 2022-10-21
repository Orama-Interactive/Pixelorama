class_name VectorCel
extends BaseCel
# A class for the properties of cels in VectorLayers.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).
# The "shapes" variable stores the cel's content, VectorShapes

var shapes := [
	{
		"type": "rect",
		"x": 5,
		"y": 20,
		"w": 12,
		"h": 16,
	},
	{
		"type": "ellipse",
		"x": 25,
		"y": 32,
		"radius": 12, # TODO: Change to w/h
	},
	{
		"type": "text",
		"x": 1,
		"y": 15,
		"text": "Hello World!"
	}
] # Array of VectorShapes

func _init(_shapes := [], _opacity := 1.0, _image_texture: ImageTexture = null) -> void:
#	shapes = _shapes
	if _image_texture:
		image_texture = _image_texture
	else:
		# TODO: Is it possible to use the viewport texture directly?
		image_texture = ImageTexture.new()
		update_texture()
	opacity = _opacity


func get_content():
	return shapes


func set_content(content, texture: ImageTexture = null) -> void:
	shapes = content
	if is_instance_valid(texture):
		image_texture = texture
		# TODO: Implement the equivalent:
#		if image_texture.get_size() != image.get_size():
#			image_texture.create_from_image(image, 0)
#	else:
#		image_texture.create_from_image(image, 0)


func create_empty_content():
	return []


func copy_content():
	return shapes.duplicate(true)


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

	for shape in shapes:
		if shape["type"] == "rect":
			VisualServer.canvas_item_add_rect(ci_rid, Rect2(shape["x"], shape["y"], shape["w"], shape["h"]), Color(0,0,1,0.5))
		elif shape["type"] == "ellipse":
			VisualServer.canvas_item_add_circle(ci_rid, Vector2(shape["x"], shape["y"]), shape["radius"], Color(1,0,0,0.5))
		elif shape["type"] == "text":
			var font := DynamicFont.new()
			font.size = 12
			font.font_data = preload("res://assets/fonts/Roboto-Regular.ttf")
			font.font_data.override_oversampling = 1
			font.outline_color = Color.red
			font.outline_size = 2
			font.draw(ci_rid, Vector2(shape["x"], shape["y"]), shape["text"])

	VisualServer.viewport_set_update_mode(vp, VisualServer.VIEWPORT_UPDATE_ONCE)
	VisualServer.viewport_set_vflip(vp, true)  # TODO: May not be needed with 2 renders
	VisualServer.force_draw(false)
	var viewport_texture := Image.new()
	viewport_texture = VisualServer.texture_get_data(VisualServer.viewport_get_texture(vp))
	VisualServer.free_rid(vp)
	VisualServer.free_rid(canvas)
	VisualServer.free_rid(ci_rid)

	# Perhaps texture_set_proxy will allow for faster updates to image_texture?

	# TODO: This should be able to be made faster:
	var shader_effect := ShaderImageEffect.new()
	shader_effect.generate_image(viewport_texture, preload("res://src/Shaders/VectorRenderColorCorrect.gdshader"), {}, Global.current_project.size)

	viewport_texture.convert(Image.FORMAT_RGBA8)
	image_texture.create_from_image(viewport_texture)
	image_texture.flags = 0
	print("VectorCel update time (msec): ", Time.get_ticks_msec() - start_msec)



func instantiate_cel_button() -> Node:
	var cel_button = Global.pixel_cel_button_node.instance()
	return cel_button
