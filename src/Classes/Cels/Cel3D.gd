class_name Cel3D
extends BaseCel

var viewport: SubViewport  ## SubViewport used by the cel.


## Class Constructor (used as [code]Cel3D.new(size, from_pxo, object_prop, scene_prop)[/code])
func _init(_viewport: SubViewport) -> void:
	viewport = _viewport
	var viewport_image := viewport.get_texture().get_image()
	image_texture = ImageTexture.create_from_image(viewport_image)


func size_changed(new_size: Vector2i) -> void:
	viewport.size = new_size
	await RenderingServer.frame_post_draw
	var viewport_image := viewport.get_texture().get_image()
	(image_texture as ImageTexture).set_image(viewport_image)


# Overridden methods


func get_image() -> Image:
	return image_texture.get_image()


func duplicate_cel() -> Cel3D:
	var new_cel := Cel3D.new(viewport)
	new_cel.opacity = opacity
	new_cel.z_index = z_index
	new_cel.user_data = user_data
	new_cel.ui_color = ui_color
	return new_cel


## Used to update the texture of the cel.
func update_texture(_undo := false) -> void:
	await RenderingServer.frame_post_draw
	var viewport_image := viewport.get_texture().get_image()
	(image_texture as ImageTexture).update(viewport_image)
	texture_changed.emit()
	# TODO: Not a huge fan of this. Perhaps we should connect the texture_changed signal
	# of every cel type to the canvas and call queue_redraw there.
	Global.canvas.queue_redraw()


func get_class_name() -> String:
	return "Cel3D"
