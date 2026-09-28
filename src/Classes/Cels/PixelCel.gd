class_name PixelCel
extends BaseCel
## A class for the properties of cels in PixelLayers.
## The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

## This variable is where the image data of the cel are.
var image: ImageExtended:
	set = image_changed


func _init(_image := ImageExtended.new(), _opacity := 1.0) -> void:
	image_texture = ImageTexture.new()
	image = _image  # Set image and call setter
	opacity = _opacity


func image_changed(value: ImageExtended) -> void:
	image = value
	if not image.is_empty() and is_instance_valid(image_texture):
		image_texture.set_image(image)


func set_indexed_mode(indexed: bool) -> void:
	image.is_indexed = indexed
	if image.is_indexed:
		image.resize_indices()
		image.select_palette("", false)
		image.convert_rgb_to_indexed()


## Grow the image so a canvas-space point is inside it,
## shifting the cel's [member offset] if needed. Returns the coordinate in the cel's local space.
func ensure_canvas_point_in_bounds(
	canvas_pos: Vector2i, change_offset_when_invisible := true
) -> Vector2i:
	if image.is_invisible() and change_offset_when_invisible:
		change_offset(snap_cel_bounds(canvas_pos))
	var local := canvas_pos - offset
	var new_offset := offset
	var new_size := image.get_size()
	if local.x < 0:
		new_size.x += -local.x
		new_offset.x += local.x
	elif local.x >= new_size.x:
		new_size.x = local.x + 1
	if local.y < 0:
		new_size.y += -local.y
		new_offset.y += local.y
	elif local.y >= new_size.y:
		new_size.y = local.y + 1
	new_size = snap_cel_bounds(new_size, true)
	new_offset = snap_cel_bounds(new_offset)
	if new_size != Vector2i(image.get_size()):
		resize_cel_image(new_size, offset - new_offset)
	if new_offset != offset:
		change_offset(new_offset)

	local = canvas_pos - offset
	return local


func ensure_canvas_rect_in_bounds(start_point: Vector2i, rect_size: Vector2i) -> void:
	var end_point := start_point + rect_size - Vector2i.ONE
	ensure_canvas_point_in_bounds(end_point)
	ensure_canvas_point_in_bounds(start_point, false)


func shrink_to_content() -> void:
	var used := image.get_used_rect()
	if used.size == image.get_size():
		return
	if used.size == Vector2i.ZERO:
		resize_cel_image(Vector2i.ONE, Vector2i.ZERO)
		return
	var used_end := snap_cel_bounds(used.end, true)
	used.position = snap_cel_bounds(used.position)
	used.end = used_end
	var new_offset := offset + used.position
	resize_cel_image(used.size, -used.position)
	change_offset(new_offset)


func resize_cel_image(new_size: Vector2i, content_offset: Vector2i) -> void:
	var new_image := Image.create_empty(new_size.x, new_size.y, false, image.get_format())
	new_image.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), content_offset)
	image.copy_from_custom(new_image)


func snap_cel_bounds(coords: Vector2i, ceil_snap := false) -> Vector2i:
	var bounds_snap := get_cel_bounds_snap()
	if bounds_snap == Vector2i.ZERO:
		return coords
	var diff: Vector2 = coords - offset
	if ceil_snap:
		diff += Vector2(bounds_snap) - Vector2.ONE
	return offset + Vector2i(diff - diff.posmodv(bounds_snap))


func blit_image_to_cel(source_image: Image) -> void:
	var used_rect := source_image.get_used_rect()
	var image_to_blit := source_image.get_region(used_rect)
	ensure_canvas_point_in_bounds(used_rect.end - Vector2i.ONE, false)
	ensure_canvas_point_in_bounds(used_rect.position, false)
	var dst := used_rect.position - offset
	image.blit_rect(image_to_blit, Rect2i(Vector2i.ZERO, image_to_blit.get_size()), dst)
	image.convert_rgb_to_indexed()


func get_cel_bounds_snap() -> Vector2i:
	return Vector2i.ZERO


func serialize() -> Dictionary:
	var dict := super()
	dict["image_size"] = var_to_str(image.get_size())
	return dict


## Reads data from a [param dict] [Dictionary], and uses them to add methods to [param undo_redo].
func deserialize_undo_data(dict: Dictionary, undo_redo: UndoRedo, undo: bool) -> void:
	if undo:
		if dict.has("offset"):
			undo_redo.add_undo_method(change_offset.bind(dict.offset))
	else:
		if dict.has("offset"):
			undo_redo.add_do_method(change_offset.bind(dict.offset))


func get_content() -> Variant:
	return image


func set_content(content, texture: ImageTexture = null) -> void:
	var proper_content: ImageExtended
	if content is not ImageExtended:
		proper_content = ImageExtended.new()
		proper_content.copy_from_custom(content, image.is_indexed)
	else:
		proper_content = content
	image = proper_content
	if is_instance_valid(texture) and is_instance_valid(texture.get_image()):
		image_texture = texture
		if image_texture.get_image().get_size() != image.get_size():
			image_texture.set_image(image)
	else:
		image_texture.update(image)


func create_empty_content() -> Variant:
	var empty := Image.create(image.get_width(), image.get_height(), false, image.get_format())
	var new_image := ImageExtended.new()
	new_image.copy_from_custom(empty, image.is_indexed)
	return new_image


func copy_content() -> Variant:
	var tmp_image := Image.create_from_data(
		image.get_width(), image.get_height(), false, image.get_format(), image.get_data()
	)
	var copy_image := ImageExtended.new()
	copy_image.copy_from_custom(tmp_image, image.is_indexed)
	return copy_image


func get_image() -> ImageExtended:
	return image


func update_texture(undo := false) -> void:
	image_texture.set_image(image)
	super.update_texture(undo)


func get_class_name() -> String:
	return "PixelCel"
